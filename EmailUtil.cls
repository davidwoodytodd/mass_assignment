public class EmailUtil {

    private String subject = '';
    private String htmlBody = '';
    private String plainTextBody = '';
    private Boolean useSignature = false;
    private Boolean SaveAsActivity = false;
    private Boolean treatTargetObjectAsRecipient = false;
    private List<Messaging.EmailFileAttachment> fileAttachments = null;

    private static User currentUser {
        get {
            if (currentUser == null)
                currentUser = [Select email from User where username = :UserInfo.getUserName() limit 1];
            return currentUser;
        } set;
    }
    private String replyTo;
    private String senderDisplayName = UserInfo.getFirstName()+' '+UserInfo.getLastName();

    private Id templateId;
    private Id whatId;

    private Id targetObjectId;
    private final List<String> toAddresses;

    private Messaging.SingleEmailMessage singleEmailMessage;


    public static EmailUtil to(List<String> addresses) {
        return new EmailUtil(addresses);
    }

    public static EmailUtil to(Id target) {
        return new EmailUtil(target);
    }


    public EmailUtil saveAsActivity(Boolean val) {
        saveAsActivity = val;
        return this;
    }
    
    public EmailUtil treatTargetObjectAsRecipient(Boolean val) {
        treatTargetObjectAsRecipient = val;
        return this;
    }

    public EmailUtil senderDisplayName(String val) {
        senderDisplayName = val;
        return this;
    }

    public EmailUtil subject(String val) {
        subject = val;
        return this;
    }

    public EmailUtil htmlBody(String val) {
        htmlBody = val;
        return this;
    }

    public EmailUtil templateId(Id an_id) {
        templateId = an_id;
        return this;
    }

    public EmailUtil whatId (Id an_id) {
        whatId = an_id;
        return this;
    }

    public EmailUtil targetObjectId (Id an_id) {
        targetObjectId = an_id;
        return this;
    }

    public EmailUtil useSignature(Boolean bool) {
        useSignature = bool;
        return this;
    }

    public EmailUtil replyTo(String val) {
        replyTo = val;
        return this;
    }

    public EmailUtil plainTextBody(String val) {
        plainTextBody = val;
        return this;
    }

    public EmailUtil fileAttachments(List<Messaging.Emailfileattachment> val) {
        fileAttachments = val;
        return this;
    }
        
    public void sendEmail() {
        // build and send email.
        build();
        last_sendEmail_result = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { singleEmailMessage });
    }
    public void stashForBulk() {
        //build and stash email.
        build();
        bulk_stash.add(singleEmailMessage);
    }

    public static void sendBulkEmail() {
        last_sendEmail_result = Messaging.sendEmail(bulk_stash);
        bulk_stash.clear();
    }

    public static Boolean hasEmailsToSend() {
        return bulk_stash.size() != 0 ? true : false;
    }

    public static Messaging.SendEmailResult[] last_sendEmail_result {get; private set;}



    // private constructors
    private EmailUtil(List<String> addresses) {
        this.toAddresses = addresses;
    }

    private EmailUtil(Id target) {
        this.targetObjectId = target;
    }



    // build method, constructs a single email message.
    // this method is private and is called from sendEmail() or stashForBulk()
    private EmailUtil build() {
        singleEmailMessage = new Messaging.SingleEmailMessage();
        singleEmailMessage.setTargetObjectId(this.targetObjectId);
        singleEmailMessage.setWhatId(this.whatId);
        singleEmailMessage.setToAddresses(this.toAddresses);
        singleEmailMessage.setSenderDisplayName(this.senderDisplayName);
        singleEmailMessage.setUseSignature(this.useSignature);
        singleEmailMessage.setFileAttachments(this.fileAttachments);
        singleEmailMessage.setSaveAsActivity(this.saveasactivity);
        singleEmailMessage.setTreatTargetObjectAsRecipient(this.treatTargetObjectAsRecipient);
        if (this.replyTo != null && this.replyTo != '') {
            singleEmailMessage.setReplyTo(this.replyTo);
        }
        // use template if one exists, else use html and plain text body
        if (this.templateId == null) {
            singleEmailMessage.setHtmlBody(this.htmlBody);
            singleEmailMessage.setPlainTextBody(this.plainTextBody);
            singleEmailMessage.setSubject(this.subject);
        } else {
            singleEmailMessage.setTemplateId(this.templateId);
        }
        return this;
    }

    private static Messaging.SingleEmailMessage[] bulk_stash {
        get {
            if (bulk_stash == null)
                bulk_stash = new Messaging.SingleEmailMessage[]{};
            return bulk_stash;
        } private set;
    }

}