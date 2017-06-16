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
            ApexPages.addMessage(new apexPages.message(apexpages.severity.error, 'No WorkOrder or Technician values were received. Please re-run from the map page.'));
            return;
        }
        List<Id> workOrderIds = new List<Id>();
        List<Id> technicianIds = new List<Id>();
        //Map<String, List<SVMXC__Service_Group_Members__c>> availTechsByProduct;

        for(Id id: sObjectIds) {
            if(id.getSobjectType() == Schema.SVMXC__Service_Order__c.SObjectType) {
                workOrderIds.add(id);
            }
            else if(id.getSobjectType() == Schema.SVMXC__Service_Group_Members__c.SObjectType) {
                technicianIds.add(id);
            }
        }

        List<SVMXC__Service_Order__c> workOrders = [SELECT Id, Name, NTT_Tech_Declined_Reason__c, SVMXC__Group_Member__c, SVMXC__Group_Member__r.Name, SVMXC__Order_Status__c, 
                                                    Special_Servicer_Code__c, BSP_Product_Line__c, BSP_WorkOrder_Distribution_List__c, SVMXC__Latitude__c, SVMXC__Longitude__c, 
                                                    Exclusion_List__c, SVMXC__Priority__c, SVMXC__Order_Type__c, Dispatch_Notes__c
                                                    FROM SVMXC__Service_Order__c WHERE (Id IN :workOrderIds)];

        List<SVMXC__Service_Group_Members__c> technicians = [SELECT Id, Name, NTT_Servicer_Type__c, SVMXC__Active__c, Special_Servicer_Code__c, NTT_Product_Line_Serviced__c, 
                                                            BSP_Product_Line_Serviced_2__c, SVMXC__Latitude__c, SVMXC__Latitude_Home__c, SVMXC__Longitude__c, SVMXC__Longitude_Home__c, 
                                                            Work_Count__c, SVMXC__Salesforce_User__c, BSP_WorkOrder_Distribution_List__c
                                                            FROM SVMXC__Service_Group_Members__c WHERE Id IN :technicianIds AND SVMXC__Active__c = true 
                                                            AND NTT_Servicer_Type__c IN :SERVTYPES ORDER BY NTT_Servicer_Type__c DESC];

        // create map of products and avail techs that can be assigned
        //availTechsByProduct = retrieveAndFilterAvailTechs(workOrders, technicianIds);

        // build WOs to be displayed on the page
        workOrderWrappers = new List<WorkOrderWrapper>();
        for(SVMXC__Service_Order__c workOrder: workOrders) {
            workOrderWrappers.add(new WorkOrderWrapper(workOrder, technicians));
        }
    }

    public PageReference save() {
        try{
            saveRecords(false);
        }
        catch(Exception ex){
            string errMsg = ex.getMessage();
            ApexPages.addMessage(new apexPages.message(apexpages.severity.error, errMsg));
        }
        return null;
    }
    
    public PageReference saveAndEmail() {
        try{
            saveRecords(true);
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
    
    public PageReference toggleFiltering() {
        return null;
    }

    private void saveRecords(Boolean sendEmail) {
        Id templateId = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Technician_Assigned_to_WorkOrder' LIMIT 1].Id;
        OrgWideEmailAddress owe = [SELECT Id, Address, DisplayName from OrgWideEmailAddress where DisplayName = 'BUNN'];
        String replyToAddress = owe.Address;
        List<SVMXC__Service_Order__c> ordersToUpdate = new List<SVMXC__Service_Order__c>();
        
        for(WorkOrderWrapper wrapper : workOrderWrappers) {
            System.debug(loggingLevel.Error, '*** wrapper: ' + wrapper);
            if(wrapper.chosenTechId == null) continue;

            wrapper.order.SVMXC__Group_Member__c = wrapper.chosenTechId;
            
            for(TechnicianDistances tech : wrapper.technicians) {
                if(tech.technician.Id == wrapper.chosenTechId) {
                    wrapper.techName = tech.technician.Name;
                    if(sendEmail) {
                        List<String> toAddresses = new List<String>((tech.technician.BSP_WorkOrder_Distribution_List__c).split(';'));
                        wrapper.order.SVMXC__Order_Status__c = 'Work Order Emailed';
                        EmailUtil.to(toAddresses)
                            .senderDisplayName(owe.DisplayName)
                            .replyTo('')
                            .templateId(templateId)
                            .targetObjectId(UserInfo.getUserId())
                            .whatId(wrapper.order.Id)
                            .treatTargetObjectAsRecipient(false)
                            .saveAsActivity(true)
                            .stashForBulk();                         
                    }
                    else {
                        wrapper.order.SVMXC__Order_Status__c = 'SA Dispatched';
                    }
                    
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
        if(EmailUtil.hasEmailsToSend()) {
            EmailUtil.sendBulkEmail();
        }
        
    }
    
    
    // this class is used to create and hold all related info for each WO row on the page
    public class WorkOrderWrapper{
        public Id woId  {get; set;}
        public Id chosenTechId {get; set;}
        public String techName {get; set;}
        public Boolean filterTechsByServ {get; set;}
        public Boolean filterTechsByProd {get; set;}
        public SVMXC__Service_Order__c order {get; set;}
        public List<TechnicianDistances> technicians {get; set;}
        public List<SelectOption> optionsList {
            get {
                optionsList = populateTechnicianOptions();
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
            this.filterTechsByServ = true;
            this.filterTechsByProd = true;
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
                    
                    if(filterTechsByServ) {
                        // filter out techs if the WO has a Spec Servicer Code and the codes do not match
                        if(order.Special_Servicer_Code__c != null && !order.Special_Servicer_Code__c.equalsIgnoreCase(tech.technician.Special_Servicer_Code__c)) continue;
                    }
                    if(filterTechsByProd) {
                        // filter out techs if product does not match
                        if(!tech.products.contains(order.BSP_Product_Line__c)) {
                            continue;
                        }
                    }
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
                return (r * c * 0.62).round();
            }

            return 99999999;
        }

        private Double toRadians(Decimal degree) {
            Double res = degree * 3.1415926 / 180;
            return res;
        }
    }


    // this class is used to sort the technicians by distance
    public class TechnicianDistances implements Comparable {
        public Decimal distanceHome;
        public Decimal distanceCurr;
        public SVMXC__Service_Group_Members__c technician;
        public Set<String> products = new Set<String>();
        
        public TechnicianDistances(Decimal distHome, Decimal distCurr, SVMXC__Service_Group_Members__c tech) {
            distanceHome = distHome;
            distanceCurr = distCurr;
            technician = tech;
            products = populateProductsSet();
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

        public Integer compareTo(Object compareTo) {
            TechnicianDistances compareToTech = (TechnicianDistances)compareTo;
            if (distanceCurr == compareToTech.distanceCurr) {
                return 0;
            }
            else if (distanceCurr > compareToTech.distanceCurr) {
                return 1;
            }
            return -1;
        }
    }


}