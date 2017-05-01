public with sharing class TechMassAssignmentController {

    public List<WorkOrderWrapper> workOrderWrappers {get; set;}
    public final List<String> SERVTYPES = new List<String>{'FSE','SSP','LSP'};

    
    public TechMassAssignmentController(){
        List<Id> sObjectIds;
        try {
            String ids = ApexPages.CurrentPage().getParameters().get('ids');
            sObjectIds = ids.split(',');
        }
        catch(Exception ex) {
            System.debug(loggingLevel.Error, '>>> Page Exception: ' + ex.getMessage() + ' : ' + ex.getStackTraceString());
            ApexPages.addMessage(new apexPages.message(apexpages.severity.error, 'No WorkOrder or Technician values were received.\nPlease re-run from the map page.'));
            return;
        }
        List<Id> workOrderIds = new List<Id>();
        List<Id> technicianIds = new List<Id>();
        Map<String, List<SVMXC__Service_Group_Members__c>> availTechsByProduct;

        for(Id id: sObjectIds) {
            if(id.getSobjectType() == Schema.SVMXC__Service_Order__c.SObjectType) {
                workOrderIds.add(id);
            }
            else if(id.getSobjectType() == Schema.SVMXC__Service_Group_Members__c.SObjectType) {
                technicianIds.add(id);
            }
        }

        List<SVMXC__Service_Order__c> workOrders = [SELECT Id, Name, NTT_Tech_Declined_Reason__c, SVMXC__Group_Member__c, SVMXC__Group_Member__r.Name, SVMXC__Order_Status__c, 
                                                    Special_Servicer_Code__c, NTT_Product_Line__c, SVMXC__Latitude__c, SVMXC__Longitude__c, Exclusion_List__c
                                                    FROM SVMXC__Service_Order__c WHERE (Id IN :workOrderIds)];

        // create map of products and avail techs that can be assigned
        availTechsByProduct = retrieveAndFilterAvailTechs(workOrders, technicianIds);

        // build WOs to be displayed on the page
        workOrderWrappers = new List<WorkOrderWrapper>();
        for(SVMXC__Service_Order__c workOrder: workOrders) {
            workOrderWrappers.add(new WorkOrderWrapper(workOrder, availTechsByProduct.get(workOrder.NTT_Product_Line__c)));
        }
    }

    private Map<String, List<SVMXC__Service_Group_Members__c>> retrieveAndFilterAvailTechs(List<SVMXC__Service_Order__c> workOrders, List<Id> technicianIds) {
        // create shell of available techs for each work order Product Line
        Map<String, List<SVMXC__Service_Group_Members__c>> productToTechsMap = new Map<String, List<SVMXC__Service_Group_Members__c>>();
        for(SVMXC__Service_Order__c order: workOrders) {
            if(!productToTechsMap.containsKey(order.NTT_Product_Line__c)) {
                productToTechsMap.put(order.NTT_Product_Line__c, new List<SVMXC__Service_Group_Members__c>());
            }
        }

        List<TechnicianWrapper> techWrappers = buildTechnicianWrappers(queryAvailTechsForAllProducts(productToTechsMap.keySet(), technicianIds));

        populateAvailTechsByProductMap(productToTechsMap, techWrappers);
        return productToTechsMap;
    }

    private List<SVMXC__Service_Group_Members__c> queryAvailTechsForAllProducts(Set<String> productSet, List<Id> technicianIds) {
        String products = '';

        for(String str : productSet) {
            products += '\'' + str + '\'' + ',';
        }
        products = products.substring(0, products.length() - 1);
        system.debug('>>> products: ' + products);

        String query = 'SELECT Id, Name, NTT_Servicer_Type__c, SVMXC__Active__c, Special_Servicer_Code__c, NTT_Product_Line_Serviced__c, BSP_Product_Line_Serviced_2__c, '
                        + 'SVMXC__Latitude__c, SVMXC__Latitude_Home__c, SVMXC__Longitude__c, SVMXC__Longitude_Home__c, Work_Count__c, SVMXC__Salesforce_User__c '
                        + 'FROM SVMXC__Service_Group_Members__c WHERE Id IN :technicianIds AND SVMXC__Active__c = true AND (NTT_Product_Line_Serviced__c INCLUDES(' + products + ') '
                        + 'OR BSP_Product_Line_Serviced_2__c INCLUDES(' + products + ')) AND NTT_Servicer_Type__c IN :SERVTYPES ORDER BY NTT_Servicer_Type__c DESC';

        List<SVMXC__Service_Group_Members__c> technicians = Database.query(query);
        return technicians;
    }

    private List<TechnicianWrapper> buildTechnicianWrappers(List<SVMXC__Service_Group_Members__c> technicians) {
        List<TechnicianWrapper> techWrappers = new List<TechnicianWrapper>();
        for(SVMXC__Service_Group_Members__c tech: technicians) {
            techWrappers.add(new TechnicianWrapper(tech));
        }
        return techWrappers;
    }

    // this method builds a map of all of the qualified techs that match the specific product line
    private void populateAvailTechsByProductMap(Map<String, List<SVMXC__Service_Group_Members__c>> productToTechsMap, List<TechnicianWrapper> techWrappers) {
        for(String productLine : productToTechsMap.keySet()) {
            for(TechnicianWrapper wrapper: techWrappers) {
                if(wrapper.products.contains(productLine)) {
                    productToTechsMap.get(productLine).add(wrapper.technician);
                }
            }
        }
    }

    public PageReference save(){
        try{
            saveRecords();
        }
        catch(Exception ex){
            string errMsg = ex.getMessage();
            ApexPages.addMessage(new apexPages.message(apexpages.severity.error, errMsg));
        }
        return null;
    }
    
    public PageReference cancel(){
        PageReference ref = new PageReference('/');
        ref.setRedirect(true);
        return ref;
    }

    private void saveRecords() {
        List<SVMXC__Service_Order__c> ordersToUpdate = new List<SVMXC__Service_Order__c>();
        for(WorkOrderWrapper wrapper : workOrderWrappers) {
            System.debug(loggingLevel.Error, '*** wrapper: ' + wrapper);
            if(wrapper.chosenTechId == null) continue;

            wrapper.order.SVMXC__Group_Member__c = wrapper.chosenTechId;
            // this is done within the workflow
            //wrapper.order.SVMXC__Order_Status__c = 'Work Order Emailed';
            for(TechnicianDistances tech : wrapper.technicians) {
                if(tech.technician.Id == wrapper.chosenTechId) {
                    wrapper.techName = tech.technician.Name;
                    if(tech.technician.SVMXC__Salesforce_User__c != null) {
                        wrapper.order.OwnerId = tech.technician.SVMXC__Salesforce_User__c;
                    }

                }
            }
            ordersToUpdate.add(wrapper.order);
        }

        if(ordersToUpdate.size() > 0) {
            update ordersToUpdate;
        }
        // creation and send of emails to techs happens within a workflow on change of SVMXC__Group_Member__c
    }
    

    // this class is used to organize techs by product line on the WOs
    public class TechnicianWrapper{
        public SVMXC__Service_Group_Members__c technician {get; set;}
        public Set<String> products {
            get {
                if(products == null) {
                    products = populateProductsSet();
                }
                return products;
            }
            set;
        }


        public TechnicianWrapper(SVMXC__Service_Group_Members__c technician){
            this.technician = technician;
        }

        private Set<String> populateProductsSet() {
            List<String> productList_1 = splitString(technician.NTT_Product_Line_Serviced__c);
            List<String> productList_2 = splitString(technician.BSP_Product_Line_Serviced_2__c);
            Set<String> allProducts = new Set<String>();
            if(productList_1 != null && productList_1.size() > 0) {
                allProducts.addAll(productList_1);
            }
            if(productList_2 != null && productList_2.size() > 0) {
                allProducts.addAll(productList_2);
            }
            return allProducts;
        }

        @TestVisible
        private List<String> splitString(String str) {
            if(str != null && str != '') {
                return str.split(';');
            }
            return null;
        }
        
    }


    // this class is used to create and hold all related info for each WO row on the page
    public class WorkOrderWrapper{
        public Id woId  {get; set;}
        public Id chosenTechId {get; set;}
        public String techName {get; set;}
        public SVMXC__Service_Order__c order {get; set;}
        public List<TechnicianDistances> technicians {get; set;}
        public List<SelectOption> optionsList {
            get {
                if(optionsList == null) {
                    optionsList = populateTechnicianOptions();
                }
                return optionsList;
            }
            set;
        }
        public Set<String> exclusions {
            get {
                exclusions = new Set<String>();
                if((exclusions == null || exclusions.size() == 0) && order.Exclusion_List__c != null) {
                    exclusions.addAll(new List<String>(order.Exclusion_List__c.split(',')));
                }
                return exclusions;
            }
            set;
        }


        public WorkOrderWrapper(SVMXC__Service_Order__c order, List<SVMXC__Service_Group_Members__c> technicians){
            this.woId = order.Id;
            this.order = order;
            this.techName = order.SVMXC__Group_Member__r.Name;
            this.technicians = calcDistancesToWO(technicians);

        }

        public List<SelectOption> getItems() {
            System.debug(loggingLevel.Error, '*** technicians: ' + technicians);
            return new List<SelectOption>(optionsList);
        }

        private List<TechnicianDistances> calcDistancesToWO(List<SVMXC__Service_Group_Members__c> techs) {
            List<TechnicianDistances> techDistances = new List<TechnicianDistances>();

            for(SVMXC__Service_Group_Members__c tech: techs) {
                Decimal distanceHome = calculateDistance(tech.SVMXC__Latitude_Home__c, tech.SVMXC__Longitude_Home__c, order.SVMXC__Latitude__c, order.SVMXC__Longitude__c);
                Decimal distanceCurr = calculateDistance(tech.SVMXC__Latitude__c, tech.SVMXC__Longitude__c, order.SVMXC__Latitude__c, order.SVMXC__Longitude__c);
                techDistances.add(new TechnicianDistances(distanceHome, distanceCurr, tech));
            }

            // this will sort all of the avail techs by Servicer Type first
            // then distance. Servicer Type order is same as SERVTYPES
            techDistances.sort();
            return techDistances;
        }

        private List<SelectOption> populateTechnicianOptions() {
            List<SelectOption> options = new List<SelectOption>();
            if(technicians.size() > 0) {
                options.add(new SelectOption('', '-- Please Select --'));
                for(TechnicianDistances tech : technicians) {
                    // filter out any exclusions
                    if(exclusions.contains(tech.technician.Id)) continue;
                    // filter out techs if the WO has a Spec Servicer Code and the codes do not match
                    if(order.Special_Servicer_Code__c != null && !order.Special_Servicer_Code__c.equalsIgnoreCase(tech.technician.Special_Servicer_Code__c)) continue;
                    options.add(new SelectOption(tech.technician.Id, createTechString(tech)));
                }
            }
            else{
                options.add(new SelectOption('', '** No technicians are available for this product line'));
            }

            return options;
        }
        
        private String createTechString(TechnicianDistances tech) {
            return tech.technician.Name + ' | ' + tech.distanceCurr + 'mi | ' + tech.distanceHome + 'mi | ' + tech.technician.NTT_Servicer_Type__c + ' | ' + String.valueOf(tech.technician.Work_Count__c == null ? 0 : tech.technician.Work_Count__c);
        }

        @TestVisible
        private Decimal calculateDistance(Decimal lat1, Decimal lon1, Decimal lat2, Decimal lon2) {
            if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
                Double r = 6371.00;
                Double dLat = toRadians(lat2 - lat1);
                Double dLon = toRadians(lon2 - lon1);
                Double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
                Double c = 2 * Math.asin(Math.sqrt(a));
                return (r * c * 0.62).setScale(3);
            }

            return 99999999;
        }

        private Double toRadians(Decimal degree) {
            Double res = degree * 3.1415926 / 180;
            return res;
        }
    }


    // this class is used to sort the technicians by servicer type and distance
    public class TechnicianDistances implements Comparable {
        public final String TYPEORDER = 'FSL';
        public Decimal distanceHome;
        public Decimal distanceCurr;
        public final Integer thisIndex;
        public SVMXC__Service_Group_Members__c technician;


        public TechnicianDistances(Decimal distHome, Decimal distCurr, SVMXC__Service_Group_Members__c tech) {
            distanceHome = distHome;
            distanceCurr = distCurr;
            technician = tech;
            thisIndex = TYPEORDER.indexOf(this.technician.NTT_Servicer_Type__c.subString(0,1));
        }

        public Integer compareTo(Object compareTo) {
            TechnicianDistances compareToTech = (TechnicianDistances)compareTo;
            if(thisIndex == TYPEORDER.indexOf(compareToTech.technician.NTT_Servicer_Type__c.subString(0,1))) {
                if (distanceCurr == compareToTech.distanceCurr) {
                    return 0;
                }
                else if (distanceCurr > compareToTech.distanceCurr) {
                    return 1;
                }
                return -1;        
            }
            else if (thisIndex > TYPEORDER.indexOf(compareToTech.technician.NTT_Servicer_Type__c.subString(0,1))) {
                return 1;
            }
            return -1;
        }
    }


}