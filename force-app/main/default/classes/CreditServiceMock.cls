@isTest
public class CreditServiceMock implements HttpCalloutMock {
    private Boolean simulateError;
    
    public CreditServiceMock(Boolean simulateError) {
        this.simulateError = simulateError;
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        if (simulateError) {
            res.setStatusCode(500);
            res.setBody('{"error": "Server Down"}');
        } else {
            res.setStatusCode(200);
            res.setBody('50'); // The mocked Credit Rating score
        }
        return res;
    }
}