# Testing Azure RM Templates with Pester

These repo contains a Pester script to test common mistake when authoring ARM Templates which can help to reduce the development time. The tests are aimed to validate:

* JSON Structure: *it doesn't have syntax errors*
* Referenced Parameters: *All parameters referenced in the json file are defined in the parameters section*
* References Variables: *All variables referenced in the json file are defined in the variables section*
* Missing opening or closing square brackets/parenthesis: *All lines aren't missing any of these two opening/closing symbols*
* Azure API Validation: *Use Test-AzureRmResourceGroupDeployment to complete validation against Azure*

More details can be found at [my blog entry](http://leandrowp.blog/2018/10/07/validating-azure-arm-templates-with-pester)