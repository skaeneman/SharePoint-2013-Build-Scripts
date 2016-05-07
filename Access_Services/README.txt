This PowerShell script reads from a corresponding XML file.  

Update only the XML file to reflect your specific SharePoint farm environment (e.g., server names, application pool, service accounts).  

The PowerShell script itself does not need to be updated only the XML file does.   

To run the script move both the .ps1 and .xml files to a SharePoint server, 
then execute the script at the Windows PowerShell console.  

The variables from the xml file get passed to the PowerShell script through calling “-XmlFilePath” 

For instance, if you were to put both the .ps1 and .xml files in a directory called “Scripts” 
under the D: drive on your server then just open a PowerShell console and navigate to that “Scripts” 
folder like below.

cd  .\Scripts

To run the script and have it read from the xml file execute the below at the PowerShell console.  
Note that the full path to the xml file must be given (e.g., “D:\Scripts\file.xml” and not just .\file.xml).

.\someScript.ps1  -XmlFilePath  "D:\Scripts\someFile.xml"
