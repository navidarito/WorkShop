public class EmailNotifier implements INotifier {
    public void notify(List<Claim__c> claims) {
        if (claims.isEmpty()) return;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] {'finance-team@yourcompany.com'});
        mail.setSubject('Claim Processing Batch Complete');
        
        String body = 'The following claims have been processed:\n\n';
        for (Claim__c c : claims) {
            body += 'ID: ' + c.Id + ' | Status: ' + c.Status__c + ' | Tax: ' + c.Tax_Amount__c + '\n';
        }
        
        mail.setPlainTextBody(body);
        
        // In a real org, you'd call Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        System.debug('Notification Sent: ' + body);
    }
}