# SharePoint 2013 Build Scripts
These PowerShell scripts read from corresponding XML files and will create the service application, service application proxy, and start the service instance on the application servers.  

Update only the XML file to reflect your specific SharePoint farm environment (e.g., server names, application pool, service accounts).  

The PowerShell script itself does not need to be updated only the XML file does.   

To run the script move both the .ps1 and .xml files to a SharePoint server, 
then execute the script at the Windows PowerShell console.  

The variables from the xml file get passed to the PowerShell script through calling “-XmlFilePath” 

For instance, if you were to put both the .ps1 and .xml files in a directory called “Scripts” 
under the D: drive on your server then just open a PowerShell console and navigate to that “Scripts” 
folder like below.

*cd  .\Scripts*

To run the script and have it read from the xml file execute the below at the PowerShell console.  
Note that the full path to the xml file must be given (e.g., “D:\Scripts\file.xml” and not just .\file.xml).

*.\someScript.ps1  -XmlFilePath  "D:\Scripts\someFile.xml"*

Add or remove the number of application servers from the xml file. 
For instance, if you have 2 application servers in the farm, 2 web servers, and a database server you
would make the xml file look like the below.  This ensures the service is started only on the 2 app servers.

        <StartServicesOnServer>
           <Server
             Name="APP_SERVER1">
           </Server>
           <Server
             Name="APP_SERVER2">
           </Server>      
        </StartServicesOnServer>

However, a 3 server farm (1 web server, 1 app server, 1 database server) would look like this

        <StartServicesOnServer>
           <Server
             Name="APP_SERVER1">
           </Server>     
        </StartServicesOnServer>

Add or remove as many application servers as necessary.

Some Service Application scripts such as Excel Services, Visio Services, and PerformancePoint will also create a Secure Store entry so the Secure Store must be deployed before those scripts can be run.

Many of the PowerShell scripts create databases, if you are using a SQL alias instead of an instance name make sure you replace this line DatabaseServer="SERVER\INSTANCE1" with DatabaseServer="Your_SQL_ALIAS"
