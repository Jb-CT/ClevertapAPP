public class MetadataDeployCallback implements Metadata.DeployCallback {
    public Boolean isCompleted = false;
    public Boolean isSuccess = false;
    public String errorMessage;
    
    public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
        isCompleted = true;
        if (result.status == Metadata.DeployStatus.Succeeded) {
            isSuccess = true;
            System.debug('Deployment succeeded');
        } else {
            isSuccess = false;
            errorMessage = result.errorMessage;
            System.debug('Deployment failed: ' + result.errorMessage);
        }
    }
}