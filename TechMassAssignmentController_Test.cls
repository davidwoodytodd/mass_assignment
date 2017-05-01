@IsTest(SeeAllData = false)
public with sharing class TechMassAssignmentController_Test {

    //  This test class covers TechMassAssignmentController.cls

    static Account acct1;
    static Account acct2;
    static Id sgId;
    static List<SVMXC__Service_Order__c> workOrders = new List<SVMXC__Service_Order__c>();
    static List<SVMXC__Service_Group_Members__c> technicians = new List<SVMXC__Service_Group_Members__c>();
    static final RecordType rt = [SELECT Id, Name, DeveloperName, SobjectType FROM RecordType WHERE SobjectType = 'SVMXC__Service_Order__c' AND DeveloperName = 'Parent'];
    static final List<String> productNames = new List<String>{'STARBUCKS_04', 'THERMOPLAN', 'SURE_TAMP_STEAM', 'NESPRESSO', 'BLACK_WHITE_CTM', 'AUTOMATIC'};
    static final List<List<String>> productValues = new List<List<String>>{
                    new List<String>{'KRAFT F15 SS','AUTOMATIC','Misc Charges','Customer Owned','Misc Allow & Chgs','AUTO'},
                    new List<String>{'BW3-CTM, WITH RF-1 MILK','BLACK_WHITE_CTM','Espresso Machine Non-Bunn','B&W3 Espresso','Espresso Category','ESP5'},
                    new List<String>{'AGUILA NESPRESSO','NESPRESSO','Equip-Competitor Equip','Equip - Competitor Equip','Cust Service Program','ESPA'},
                    new List<String>{'DUAL SH DBC,120/208GRY SBUX','STARBUCKS_04','Systems-Dual','Dual Starbucks','Systems Category','OTHRS'},
                    new List<String>{'SURE TAMP STEAM','SURE_TAMP_STEAM','Espresso Machine BUNN','Sure Tamp Steam 2 Step','Espresso Category','SURE'},
                    new List<String>{'STARBUCKS V801','THERMOPLAN','Equip-Competitor Equip','Equip - Competitor Equip','Cust Service Program','ESPS'}};
    static final List<List<Decimal>> acctLatLongs = new List<List<Decimal>>{new List<Decimal>{40.631, -73.947},
                                                               new List<Decimal>{40.646, -73.984},
                                                               new List<Decimal>{40.577, -73.962},
                                                               new List<Decimal>{40.744, -74.051},
                                                               new List<Decimal>{40.730, -73.812},
                                                               new List<Decimal>{40.701, -73.935}};
    static final List<List<Decimal>> techLatLongs = new List<List<Decimal>>{new List<Decimal>{40.725, -73.987},
                                                               new List<Decimal>{40.721, -73.957},
                                                               new List<Decimal>{40.682, -73.975},
                                                               new List<Decimal>{40.768, -73.957}};


    @testSetup
    static void setup() {
        List<Product2> productsToInsert = new List<Product2>();

        acct1 = createNewAccount('Reily');
        acct2 = createNewAccount('');
        insert new List<Account>{acct1, acct2};

        sgId = createServiceGroup();

        // create 4 techs; 2 Reily, 2 null
        for(Integer i = 0; i < techLatLongs.size(); i++) {
            SVMXC__Service_Group_Members__c newTech = createGroupMember(techLatLongs[i], i < 2 ? 'Reily' : '', i);
            technicians.add(newTech);
        }
        insert technicians;

        // create 6 work orders & 6 products; 4 WOs for acct1, 2 for acct2
        for(Integer i = 0; i < productNames.size(); i++) {
            productsToInsert.add(createProduct(productValues[i]));
            workOrders.add(createServiceOrder(productNames[i], acctLatLongs[i], i < 4 ? acct1.Id : acct2.Id));
            if(i == 1) {
                // add an Exclusion to one of the WOs
                workOrders[1].Exclusion_List__c = technicians[1].Id;
            }
        System.debug(loggingLevel.Error, '*** workOrders: ' + workOrders);
        }
        insert workOrders;
    }

    private static Account createNewAccount(String code) {
        return new Account(
            Name = 'A Test Account Inc ' + code,
            Special_Servicer_Code__c = code,
            BillingStreet = '123 Main St',
            BillingCity = 'Charlotte',
            BillingState = 'NC',
            BillingPostalCode = '12345',
            ShippingStreet = '123 Main St',
            ShippingCity = 'Charlotte',
            ShippingState = 'NC',
            ShippingPostalCode = '12345',
            Phone = '2222222222'
        );
    }

    private static Product2 createProduct(List<String> productInfo) {
        return new Product2(
            Name = productInfo[0],
            SVMXC__Product_Line__c = productInfo[1],
            Product_Group__c = productInfo[2],
            Product_Model__c = productInfo[3],
            ProductCode = 'prod',
            IsActive = true,
            Family = productInfo[4],
            BSP_Service_Category__c = productInfo[5]
        );
    }

    private static SVMXC__Service_Order__c createServiceOrder(String productName, List<Decimal> latLong, Id acctId) {
        return new SVMXC__Service_Order__c(
            RecordTypeId = rt.Id,
            NTT_Product_Line__c = productName, 
            SVMXC__Company__c = acctId,
            SVMXC__Latitude__c = latLong[0],
            SVMXC__Longitude__c = latLong[1],
            SVMXC__Order_Status__c = 'OPEN',
            SVMXC__Order_Type__c = 'Service',
            SVMXC__Priority__c = 'PLANNED'
        );
    }

    private static Id createServiceGroup() {
        SVMXC__Service_Group__c sg = new SVMXC__Service_Group__c(
            Name = 'US EAST TEST',
            SVMXC__Active__c = true,
            SVMXC__Group_Type__c = 'Both'
        );
        insert sg;
        return sg.Id;
    }

    private static SVMXC__Service_Group_Members__c createGroupMember(List<Decimal> latLong, String code, Integer i) {
        List<String> servicerTypes = new List<String>{'FSE','FSE','SSP','LSP'};
        return new SVMXC__Service_Group_Members__c(
                Name = 'John Doe - ' + DateTime.now().millisecond(),
                NTT_Product_Line_Serviced__c = String.join(productNames, ';'),
                BSP_Product_Line_Serviced_2__c = 'ESPRESSO',
                NTT_Servicer_Type__c = servicerTypes.get(i),
                SVMXC__Active__c = true,
                Special_Servicer_Code__c = code,
                SVMXC__Latitude__c = latLong[0],
                SVMXC__Latitude_Home__c = latLong[0],
                SVMXC__Longitude__c = latLong[1],
                SVMXC__Longitude_Home__c = latLong[1],
                SVMXC__Service_Group__c = sgId
        );
    }


    private static PageReference setupTestObjects() {
            List<Id> workOrderIds = new List<Id>();
            List<Id> technicianIds = new List<Id>();

            Map<Id, SVMXC__Service_Order__c> woMap = new Map<Id, SVMXC__Service_Order__c>([SELECT Id FROM SVMXC__Service_Order__c WHERE CreatedDate = TODAY AND CreatedById = :UserInfo.getUserId()]);
            workOrderIds = new List<Id>(woMap.keySet());
            workOrders = new List<SVMXC__Service_Order__c>(woMap.values());

            Map<Id, SVMXC__Service_Group_Members__c> techsMap = new Map<Id, SVMXC__Service_Group_Members__c>([SELECT Id FROM SVMXC__Service_Group_Members__c WHERE CreatedDate = TODAY AND CreatedById = :UserInfo.getUserId()]);
            technicianIds = new List<Id>(techsMap.keySet());
            technicians = new List<SVMXC__Service_Group_Members__c>(techsMap.values());

            PageReference pr = new PageReference('apex/MA_Mass_Tech_Assignment?ids=' + String.join(workOrderIds, ',') + ',' + String.join(technicianIds, ',') + '&sfdc.override=1');
            return pr;
    }


    
    @isTest
    public static void test_No_Ids() {
        // simulate no ids passed in; forces exception and page message
        PageReference pr = new PageReference('apex/MA_Mass_Tech_Assignment');
        Test.setCurrentPage(pr);

        Test.startTest();

        TechMassAssignmentController massAssignController = new TechMassAssignmentController();
        System.assert(ApexPages.hasMessages());
        System.assert(ApexPages.getMessages().get(0).getSummary().contains('No WorkOrder or Technician values were received'));

        Test.stopTest();
    }

    @isTest
    public static void test_Cancel_Button() {
        PageReference pr = setupTestObjects();
        Test.setCurrentPage(pr);
        System.assertEquals(pr.getUrl(), ApexPages.currentPage().getUrl(), pr.getUrl());

        Test.startTest();

        TechMassAssignmentController massAssignController = new TechMassAssignmentController();

        // simulate press cancel button
        PageReference pgFromCont = massAssignController.cancel();

        // did we get the correct redirect?
        System.assertEquals(new PageReference('/').getUrl(), pgFromCont.getUrl());

        Test.stopTest();
    }

    @isTest
    public static void test_LoadPageWithCorrectValues() {
        PageReference pr = setupTestObjects();
        Test.setCurrentPage(pr);

        Test.startTest();

        TechMassAssignmentController massAssignController = new TechMassAssignmentController();

        // simulate populating items picklist on page
        List<SelectOption> items = massAssignController.workOrderWrappers[0].getItems();
        System.assertEquals(3, items.size());

        // test Calculate Distance with missing parameter
        Decimal val = massAssignController.workOrderWrappers[0].calculateDistance(null, null, null, null);
        System.assertEquals(99999999, val);

        // test splitString returns null
        TechMassAssignmentController.TechnicianWrapper tw = new TechMassAssignmentController.TechnicianWrapper(technicians[0]);
        List<String> retStr = tw.splitString('');
        System.assertEquals(null, retStr);

        Test.stopTest();
    }

    @isTest
    public static void test_NoAvailTechs() {
        PageReference pr = setupTestObjects();
        Test.setCurrentPage(pr);

        Test.startTest();

        TechMassAssignmentController massAssignController = new TechMassAssignmentController();

        // simulate creating empty picklist of techs
        massAssignController.workOrderWrappers[0].technicians.clear();
        List<SelectOption> items = massAssignController.workOrderWrappers[0].getItems();
        System.assertEquals(1, items.size());

        Test.stopTest();
    }

    @isTest
    public static void test_LoadPage_ChangeTech() {
        PageReference pr = setupTestObjects();
        Test.setCurrentPage(pr);

        Test.startTest();

        TechMassAssignmentController massAssignController = new TechMassAssignmentController();

        // assert that controller created all wrappers correctly
        System.assertEquals(workOrders.size(), massAssignController.workOrderWrappers.size());

        Id techId = massAssignController.workOrderWrappers[0].technicians[1].technician.Id;
        //massAssignController.workOrderWrappers[0].technicians[1].technician.SVMXC__Salesforce_User__c = techUser.Id;

        // simulate changing a technician from the page
        massAssignController.workOrderWrappers[0].chosenTechId = techId;

        // simulate save action
        massAssignController.save();

        // assert saved changes correctly
        SVMXC__Service_Order__c queriedWO = [SELECT Id, SVMXC__Group_Member__c FROM SVMXC__Service_Order__c WHERE Id = :massAssignController.workOrderWrappers[0].order.Id];
        System.assertEquals(techId, queriedWO.SVMXC__Group_Member__c);
        
        Test.stopTest();
    }

    @isTest
    public static void test_FailSaveEvent() {
        PageReference pr = setupTestObjects();
        Test.setCurrentPage(pr);

        Test.startTest();

        TechMassAssignmentController massAssignController = new TechMassAssignmentController();

        Id techId = technicians[1].Id;

        // change a technician
        massAssignController.workOrderWrappers[0].chosenTechId = techId;
        // remove Id to force error
        massAssignController.workOrderWrappers[0].order.Id = null;

        // simulate save action
        massAssignController.save();
        // check that error was caught and message was added
        System.assert(ApexPages.hasMessages());
        System.assertEquals(1, ApexPages.getMessages().size(), ApexPages.getMessages().get(0).getSummary());
        
        Test.stopTest();
    }
    

}