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
# Reference and Demo Data setup

You can find publicly available reference and annotation files necessary for these workflows. 

References and Annotation<br/>
[https://datasetpbhumanwgs.blob.core.windows.net/?sv=2021-06-08&ss=bfqt&srt=sco&sp=rlpitfx&se=2025-10-11T03:59:01Z&st=2022-10-10T20:24:01Z&spr=https&sig=NB%2B78ujhUPKPLuD4IBjkUHPGMtbw2euXkiYmvB73gjs%3D](https://datasetpbhumanwgs.blob.core.windows.net/?sv=2021-06-08&ss=bfqt&srt=sco&sp=rlpitfx&se=2025-10-11T03:59:01Z&st=2022-10-10T20:24:01Z&spr=https&sig=NB%2B78ujhUPKPLuD4IBjkUHPGMtbw2euXkiYmvB73gjs%3D)

We have included two demo datasets with this workflow to demonstrate use cases.

Genome in a Bottle<br>
[https://datasetgiab.blob.core.windows.net/?sv=2020-04-08&st=2021-06-17T16%3A35%3A11Z&se=2021-06-18T16%3A35%3A11Z&sr=b&sp=r&sig=o%2Bj2%2FfT%2Bp2nyw8yb1MSvSGnU%2BOtJTgYjo7gwdVfgTLs%3D](https://datasetgiab.blob.core.windows.net/?sv=2020-04-08&st=2021-06-17T16%3A35%3A11Z&se=2021-06-18T16%3A35%3A11Z&sr=b&sp=r&sig=o%2Bj2%2FfT%2Bp2nyw8yb1MSvSGnU%2BOtJTgYjo7gwdVfgTLs%3D)
sv=2020-04-08&st=2021-06-17T16%3A35%3A11Z&se=2021-06-18T16%3A35%3A11Z&sr=b&sp=r&sig=o%2Bj2%2FfT%2Bp2nyw8yb1MSvSGnU%2BOtJTgYjo7gwdVfgTLs%3D)

Ashkenazi Trio<br>
[https://datasetpbhumandemodata.blob.core.windows.net/?sv=2021-06-08&ss=bfqt&srt=sco&sp=rlpitfx&se=2025-10-11T03:59:12Z&st=2022-10-10T20:19:12Z&spr=https&sig=l8HQn6XM78YJGCyqGweSmJM4h%2BnY94iAgXMWrZuDk04%3D](https://datasetpbhumandemodata.blob.core.windows.net/?sv=2021-06-08&ss=bfqt&srt=sco&sp=rlpitfx&se=2025-10-11T03:59:12Z&st=2022-10-10T20:19:12Z&spr=https&sig=l8HQn6XM78YJGCyqGweSmJM4h%2BnY94iAgXMWrZuDk04%3D)
sv=2020-04-08&st=2021-06-17T16%3A35%3A11Z&se=2021-06-18T16%3A35%3A11Z&sr=b&sp=r&sig=o%2Bj2%2FfT%2Bp2nyw8yb1MSvSGnU%2BOtJTgYjo7gwdVfgTLs%3D)

You can use these input file URLs + SAS directly as they are publicly available or you can [mount the storage account](https://github.com/microsoft/CromwellOnAzure/blob/main/docs/troubleshooting-guide.md#use-input-data-files-from-an-existing-azure-storage-account-that-my-lab-or-team-is-currently-using) in your Cromwell on Azure instance <br/>

Alternatively, you can choose to upload the data into the "dataset" container in your Cromwell on Azure storage account associated with your host VM.
You can use [AzCopy](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-blobs#copy-a-container-to-another-storage-account) to transfer the required files to your own Storage account [using a shared access signature](https://docs.microsoft.com/en-us/azure/storage/common/storage-sas-overview) with "Write" access.<br/>

```[//]: # ([SuppressMessage\("Microsoft.Security", "CS002:SecretInNextLine", Justification="public dataset"\)]) 
.\azcopy.exe copy 'https://datasetpbhumanwgs.blob.core.windows.net/?sv=2021-06-08&ss=bfqt&srt=sco&sp=rlpitfx&se=2025-10-11T03:59:01Z&st=2022-10-10T20:24:01Z&spr=https&sig=NB%2B78ujhUPKPLuD4IBjkUHPGMtbw2euXkiYmvB73gjs%3D' 'https://<destination-storage-account-name>.blob.core.windows.net/dataset?<WriteSAS-token>' --recursive --s2s-preserve-access-tier=false
```
You can also do this directly from the Azure Portal, or use other tools including [Microsoft Azure Storage Explorer](https://azure.microsoft.com/features/storage-explorer/) or [blobporter](https://github.com/Azure/blobporter). <br/>

**Note**
Some files were reformated for this pipeline. You could also generate new versions by downloading raw references and pass them to the references.wdl to generate modified reference files or download modified references files from Pacbio.

1. Clinvar: ftp://ftp.ncbi.nlm.nih.gov/pub/clinvar/gene_condition_source_id
2. LOF: https://storage.googleapis.com/gnomad-public/release/2.1.1/constraint/gnomad.v2.1.1.lof_metrics.by_gene.txt.bgz
3. GFF: ftp://ftp.ensembl.org//pub/release-101/gff3/homo_sapiens/Homo_sapiens.GRCh38.101.gff3.gz

For any further questions please contact one of the repository contributors or, if applicable, your PacBio representative to request these materials.
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

If you choose **NOT** to do this, an alternative way of specifying the path to your data is to provide the URL + SAS token to your files directly in the input JSON file. For more information see [Create SAS tokens for your storage containers](https://learn.microsoft.com/en-us/azure/cognitive-services/translator/document-translation/create-sas-tokens?tabs=Containers). An example of this using the same data is below.
"path": https://datasetgiab.blob.core.windows.net/dataset/data/AshkenazimTrio/HG002_NA24385_son/PacBio_SequelII_CCS_11kb/reads/m64011_181218_235052.fastq.gz?sv=2020-04-08&st=2021-06-17T16%3A35%3A11Z&se=2021-06-18T16%3A35%3A11Z&sr=b&sp=r&sig=o%2Bj2%2FfT%2Bp2nyw8yb1MSvSGnU%2BOtJTgYjo7gwdVfgTLs%3D

**Note**: For file you can't provide a public URL for input files, certain functions in Cromwell will not work. 

4. When you are done editing the file for your dataset, upload it to your "Inputs" container in your Cromwell on Azure setup. Copy the URL of this file.
5. Download & open your Trigger file in your editor.
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
Cloning the repository into your own Github Account has numerous benefits- namely the ability to easily customize the workflow to your choosing, while still having version control. This does require a bit of prior experience with Github to setup- as you'll need to update the URLs in your WDLs to point to your storage location for the imported components of the workflows. The Cromwell documentation provides information about sourcing locally stored WDLs. To change the URLs in all imports in your fork use the BASH script `rename_urls.sh`.

