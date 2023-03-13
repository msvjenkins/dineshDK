$cvs_client_list_env = $args[0]
$cvs_env_dir = $args[1]
$target_clientid = $args[2]
$target_country_code = $args[3]
$target_cvs_server_ip = $args[4]
$cvs_port_no = $args[5]

write-output "Adding entry in clientlist.xml in $cvs_client_list_env environment"
write-output "Received parameters"
write-output "CVS environment : $cvs_client_list_env "
write-output "CVS environment path : $cvs_env_dir"
write-output "Target clientid : $target_clientid"
write-output "Target countrycode : $target_country_code"
write-output "CVS domain name : $target_cvs_server_ip"
write-output "CVS port no : $cvs_port_no"


[xml]$XmlDocument_cvs_clientlist = get-content "$cvs_env_dir\client_list.xml"
$XmlDocument_cvs_clientid=$XmlDocument_cvs_clientlist.CreateNode("element","$target_clientid","")
$XmlDocument_cvs_countrycode=$XmlDocument_cvs_clientlist.CreateNode("element","$target_country_code","")
$XmlDocument_cvs_protocoltype=$XmlDocument_cvs_clientlist.CreateNode("element","cvs_protocol_type","")
$XmlDocument_cvs_domainname=$XmlDocument_cvs_clientlist.CreateNode("element","cvs_domain_name","")
$XmlDocument_cvs_portno=$XmlDocument_cvs_clientlist.CreateNode("element","cvs_port_no","")
$XmlDocument_cvs_countrycode.AppendChild($XmlDocument_cvs_protocoltype)
$XmlDocument_cvs_countrycode.AppendChild($XmlDocument_cvs_domainname)
$XmlDocument_cvs_countrycode.AppendChild($XmlDocument_cvs_portno)
$XmlDocument_cvs_clientid.AppendChild($XmlDocument_cvs_countrycode)
$XmlDocument_cvs_clientlist.client_list.PrependChild($XmlDocument_cvs_clientid)
$XmlDocument_cvs_clientlist.save("$cvs_env_dir\client_list.xml")
if ("$?" -eq 'False')
	{
		write-output "Error in saving client_list xml file in $cvs_client_list_env environment"									
		exit 1
	}
	
write-output "adding entry"
[xml]$XmlDocument_cvs_clientlistentry = get-content "$cvs_env_dir\client_list.xml"	
write-output "$XmlDocument_cvs_clientlistentry.client_list.$target_clientid.$target_country_code.cvs_protocol_type = http"
$XmlDocument_cvs_clientlistentry.client_list.$target_clientid.$target_country_code.cvs_protocol_type = "http"
write-output "$XmlDocument_cvs_clientlistentry.client_list.$target_clientid.$target_country_code.cvs_domain_name = $target_cvs_server_ip"
$XmlDocument_cvs_clientlistentry.client_list.$target_clientid.$target_country_code.cvs_domain_name = "$target_cvs_server_ip"
write-output "$XmlDocument_cvs_clientlistentry.client_list.$target_clientid.$target_country_code.cvs_port_no = $cvs_port_no"
$XmlDocument_cvs_clientlistentry.client_list.$target_clientid.$target_country_code.cvs_port_no = "$cvs_port_no"
write-output "$XmlDocument_cvs_clientlistentry.save($cvs_env_dir\client_list.xml)"
$XmlDocument_cvs_clientlistentry.save("$cvs_env_dir\client_list.xml")
if ("$?" -eq 'False')
	{
		write-output "Error in saving client_list xml file in $cvs_client_list_env environment"									
		exit 1
	}
if ("$?" -eq 'True')
	{
		write-output "Entries in client_list xml added successfully in $cvs_client_list_env environment"									
		exit 0
	}	

