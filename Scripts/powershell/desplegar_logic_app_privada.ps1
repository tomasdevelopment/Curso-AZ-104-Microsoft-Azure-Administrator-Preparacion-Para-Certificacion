$tmpl="C:\Users\tomsuare\Desktop\iaac\iaactemplates\logicappdeploy\template.json"; `
$param="C:\Users\tomsuare\Desktop\iaac\iaactemplates\logicappdeploy
$rg="MPPGPUSE2BIZOPSWORKSRG"
$loc="eastus2"
New-AzResourceGroupDeployment `
  -ResourceGroupName $rg`
  -TemplateFile $tmpl
 -TemplateParameterFile $param
 -Mode Incremental
  -contentStorageAccountName  =yourstorage `
  -contentStorageAccountResourceGroup $rg 
