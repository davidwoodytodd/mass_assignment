@IsTest(SeeAllData=true)
public class EmailUtils_Test {

    private static User currentUser {
        get {
            if (currentUser == null)
                currentUser = [Select email from User where username = :UserInfo.getUserName() limit 1];
            return currentUser;
        } set;
    }

    private static testMethod void should_store_email_results() {
        // Given an email util that hasn't sent emails
        System.assertEquals(null, EmailUtil.last_sendEmail_result);

        // When you send an email
        EmailUtil.to(new String[]{'test@spam.com'}).sendEmail();

        // Then the email util should store the send result.
        System.assertNotEquals(null, EmailUtil.last_sendEmail_result);
        System.assertEquals(1, EmailUtil.last_sendEmail_result.size());
        for (Messaging.SendEmailResult ser : EmailUtil.last_sendEmail_result)
            System.assertEquals(true, ser.isSuccess());
    }

    private static testMethod void should_work_with_templates() {
        // Given an email util that has not sent emails, and a template for emails
        System.assertEquals(null, EmailUtil.last_sendEmail_result);

        Folder test_template_folder =
            [Select Id from Folder Where Type = 'Email' And IsReadOnly = false Limit 1];

        EmailTemplate test_template = new EmailTemplate(
            Name = 'test email template', DeveloperName = 'test_template_uniqueasdfbahkls',
            TemplateType = 'text', isActive = true, Description = 'test template',
            Subject = 'test email', FolderId = test_template_folder.Id,
            Body = 'Hi {!Receiving_User.FirstName}, this is a test email to a user.'
        );
        insert test_template;

        // When an email is constructed & sent to the current user with that template
        EmailUtil.to(new String[]{'test@spam.com'})
            .templateId(test_template.Id)
            .targetObjectId(UserInfo.getUserId())
            .sendEmail();

        // Then it should be sent successfully
        System.assertEquals(1, EmailUtil.last_sendEmail_result.size());
        for (Messaging.SendEmailResult ser : EmailUtil.last_sendEmail_result)
            System.assertEquals(true, ser.isSuccess());
    }

    private static testMethod void should_bulk_stash() {
        // Given an EmailUtil that doesn't have emails to send.
        System.assertEquals(false, EmailUtil.hasEmailsToSend());

        // When you stash an email to send
        EmailUtil.to(new String[]{'test@spam.com'})
            .stashForBulk();

        // Then EmailUtil should have emails to send
        System.assertEquals(true, EmailUtil.hasEmailsToSend());
    }

    private static testMethod void should_bulk_send() {
        // Given an Email util with  bulk email to send
        EmailUtil.to(new String[]{'test1@spam.com'}).stashForBulk();
        EmailUtil.to(new String[]{'test2@spam.com'}).stashForBulk();

        // When you send bulk
        EmailUtil.sendBulkEmail();

        // Then two emails should be sent successfully
        system.assertEquals(2, EmailUtil.last_sendEmail_result.size());
        for (Messaging.SendEmailResult ser : EmailUtil.last_sendEmail_result)
            System.assertEquals(true, ser.isSuccess());
    }

    private static testMethod void should_gracefully_handle_empty_bulk_send() {
        // Given an emailutil with no emails to send
        System.assertEquals(false, EmailUtil.hasEmailsToSend());

        try {
            // When you try and do a bulk send
            EmailUtil.sendBulkEmail();
        } catch (Exception e) {
            // then it shouldn't fail horribly.
            System.assert(false);
        }
    }

    private static testMethod void setters_should_not_throw_exceptions() {
        try {
            // When using all the setters
            EmailUtil.to(new String[]{currentUser.email})
                .saveAsActivity(false)
                .senderDisplayName('test sender')
                .subject('test email')
                .htmlBody('this is html')
                .useSignature(false)
                .replyTo(currentUser.email)
                .plainTextBody('this is plaintext')
                .fileAttachments(null);
        } catch (Exception e) {
            // Then it should not throw an exception.
            system.assert(false);
        }
    }
    
}