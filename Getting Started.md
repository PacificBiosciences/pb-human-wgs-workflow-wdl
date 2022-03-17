# Getting Started
This is a simple walk through guide for getting started with running the pbhumanWGS workflows with Cromwell on Azure. This workflow has been optimized to run with its current default settings with Cromwell on Azure, leveraging Azure Batch and Azure Blob Storage for managing the workflow processing. Some minor adaptations to runtime parameters might be necessary for these WDLs to operate in other Cromwell deployments.
________________________________________
# Prerequisites
1.	A Microsoft Azure Account.
2.	Deploy Cromwell on Azure using this guide.
3.	Upload your data (HiFi reads in BAM or FASTQ format) to an Azure Blob Storage Container. A quick and easy interface to drag and drop your files from your local computer to Azure is the Azure Storage Explorer, which is available for Windows, Mac, or Linux operating systems.
________________________________________
# Initial setup
When initially deployed, Cromwell on Azure mounts any container listed within the "Containers-to-Mount" configuration file, which is located in the "Configuration" container in any Cromwell on Azure deployment. For Cromwell on Azure I'to see your data, you can choose to use 1 of 3 methods for granting Cromwell on Azure access to your data.
1.	Place your data directly within the "Inputs" container provided by Cromwell. You can move your data to Azure with Azure Storage Explorer in a drag-and-drop application, or with AzCopy via a CLI for any OS. (Easiest method- recommended if you're just getting started on Azure or just testing out the workflow).
2.	Create a temporary Shared Access Signature (SAS) token, and share that SAS token with Cromwell. (Recommended for long term deployments.)
3.	Grant the Managed Identity in your Cromwell on Azure Resource Group permission to access your private storage account. (Requires access to Azure Portal or az cli.)
________________________________________
# Starting a run 
## Quick Start Option (Recommended): Download & Edit the Trial Inputs & Trigger Files
This method will allow you to get started quickly. We have included a demo dataset (from the Genomics Data Lake) with this workflow to demonstrate use cases.
1.	Download the smrtcells trial input JSON.
2.	Open the file in your favorite text editor. A couple of options that work well are Visual Studio Code or Notepad++.
3.	The JSON file is labeled with various input fields you can define. You will need to specify a sample name, 1 or more SMRT cells, the paths to the raw data files, and if they are BAM files or not.
	'''
    {
	 "smrtcells_trial.cohort": {
	     "affected_persons": [
	     {
	     "name": "HG002_NA24385_son",  
	     "smrtcells": [
	         {
	         "name": "m64011_181218_235052", 
	         "path": "/datasetgiab/dataset/data/AshkenazimTrio/HG002_NA24385_son/PacBio_SequelII_CCS_11kb/reads/m64011_181218_235052.fastq.gz", 
	         "isUbam": false
	         },
	     ]
	 }     
	 ],
	 "unaffected_persons": [
	     ]
	     }
	 } 
     '''

A note about specifying file paths- if you followed the directions for Initial Setup, you can simply refer to your files using the syntax /<storageAccountName>/containername. In the code snippet above, datasetgiab is the storage account name, and dataset is the container name.

If you choose NOT to do this, an alternative way of specifying the path to your data is to provide the URL + SAS token to your files directly in the input JSON file. An example of this using the same data is below.
"path": https://datasetgiab.blob.core.windows.net/dataset/data/AshkenazimTrio/HG002_NA24385_son/PacBio_SequelII_CCS_11kb/reads/m64011_181218_235052.fastq.gz?sv=2020-04-08&st=2021-06-17T16%3A35%3A11Z&se=2021-06-18T16%3A35%3A11Z&sr=b&sp=r&sig=o%2Bj2%2FfT%2Bp2nyw8yb1MSvSGnU%2BOtJTgYjo7gwdVfgTLs%3D

When you are done editing the file for your dataset, upload it to your "Inputs" container in your Cromwell on Azure setup. Copy the URL of this file.
5.	Download & open your Trigger file in your editor.
    '''
    {
    "WorkflowUrl": "smrtcells/smrtcells.trial.wdl"
    "WorkflowInputsUrls": [
        "smrtcells/inputs/AshkenazimTrio/trial.singleton.inputs.json",
        "smrtcells/inputs/defaultsettings.trial.inputs.json",
        "smrtcells/inputs/docker.trial.inputs.json",
        "smrtcells/inputs/reference.trial.inputs.json"
        ],
     "WorkflowOptionsUrl": null,
     "WorkflowDependenciesUrl": null
    }
    '''
6. You'll want to replace the path to your trial data input file (with the path to the input JSON that you just uploaded). Save this file locally.
7. Upload the trigger file to the workflow/new container in your file.

**Congratulations**- you've started your analysis!
## Option 2: Clone this repository & customize the workflow
Cloning the repository into your own Github Account has numerous benefits- namely the ability to easily customize the workflow to your choosing, while still having version control. This does require a bit of prior experience with Github to setup- as you'll need to update the URLs in your WDLs to point to your storage location for the imported components of the workflows. The Cromwell documentation provides information about sourcing locally stored WDLs.
