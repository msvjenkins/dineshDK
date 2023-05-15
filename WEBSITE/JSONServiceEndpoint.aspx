<%@ Page Language="C#" AutoEventWireup="true" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Reflection" %>
<%@ Import Namespace="System.Runtime.Serialization" %>
<%@ Import Namespace="System.Xml" %>
<%@ Import Namespace="UmoldITLibraries" %>
<%@ Import Namespace="CustomLibraries" %>

<script runat="server">
    
    protected void Page_Load(object sender, EventArgs e)
    {
        XmlDocument xmlIn = new XmlDocument();
        XmlDocument xmlOut = null;
        string serviceStartTime, serviceEndTime;
        serviceStartTime = DateTime.Now.ToString("dd-MMM-yyyy hh:mm:ss.fff");
        Dictionary<object, object> contextDataItems = null;
        CustomLogger customLogger = new CustomLogger();
        
        //Retrieving application name, service name and output list name along with its hierarchy (if any) from querystring
        string applicationName = Request.QueryString["appName"];
        string serviceName = Request.QueryString["serviceName"];
        string outputListpath = "", outputListName = "", serviceInputJSON = "", serviceOutputJSON = "";
        bool isOutListMentioned = false;
                
        if (customLogger.serviceLogging)
        {
            customLogger.buildLogmessage("Inside JSONServiceEndpoint.aspx for " + applicationName + "." + serviceName );
        }
        
        if (Request.QueryString.Count > 2)
        {
            outputListpath = Request.QueryString["path"];
            string[] xpath = outputListpath.Split('/');
            outputListName = xpath[xpath.Length - 1].ToString();
            isOutListMentioned = true;
        }

        try
        {
            System.IO.StreamReader sr = new System.IO.StreamReader(Request.InputStream);
            serviceInputJSON = sr.ReadToEnd();

			if (customLogger.serviceLogging)
            {
                customLogger.buildLogmessage("Inside " + serviceName + " endpoint (.aspx)", new Dictionary<object, object> { { "Input payload (JSON)", serviceInputJSON } });
            }
            
            xmlIn = Utilities.ConvertJsonStringToXml(serviceInputJSON);

			if (customLogger.serviceLogging)
            {
                customLogger.buildLogmessage("Inside " + serviceName + " endpoint (.aspx)", new Dictionary<object, object> { { "xmlIn", xmlIn.OuterXml } });
            }
            //Processing service context data items
            contextDataItems = new Dictionary<object, object>();
            foreach (XmlNode node in xmlIn.FirstChild.SelectSingleNode("./context").ChildNodes)
            {
                if (node.LastChild.NodeType == XmlNodeType.Text)
                {
                    contextDataItems.Add(node.Name, node.InnerText);
                }
            }
            if (CustomUtil.isSessionValid(contextDataItems, applicationName, serviceName))
            {
                //Service input structure/data validation
                Utilities.validateXmlSchema(xmlIn, applicationName, serviceName + ".InputMessage.xsd");

                //Service invocation
                Assembly assemInstance = Assembly.Load(applicationName);
                object assemblyObj = assemInstance.CreateInstance(applicationName + "." + serviceName);
                if (assemblyObj == null)
                {
                    throw new Exception("Class '" + applicationName + "." + serviceName + "' cannot be instantiated, as there is no such class definition in the assembly '" + applicationName + "'");
                }
                
                object[] methodParams = null;
                if ((assemblyObj.GetType()).GetMethods()[0].GetParameters().Length > 2 && (assemblyObj.GetType()).GetMethods()[0].GetParameters()[2].ParameterType.Name == "CustomLogger")
                    methodParams = new Object[] { xmlIn, xmlOut, customLogger };
                else 
                    methodParams = new Object[] { xmlIn, xmlOut};
                                        
                (assemblyObj.GetType()).InvokeMember("invokeBusinessLogic", BindingFlags.Public | BindingFlags.Instance | BindingFlags.InvokeMethod, null, assemblyObj, methodParams);
                xmlOut = methodParams.GetValue(1) as XmlDocument;
                
                //Service response processing
                if (xmlOut.FirstChild.SelectSingleNode("./context") != null)
                {
                    Utilities.validateXmlSchema(xmlOut, applicationName, serviceName + ".OutputMessage.xsd");
                }
            }
            else
            {
                throw new Exception("Invalid session");
            }
        }
        catch (Exception exp)
        {
            string expMessage = exp.Message;
            if (exp.InnerException != null)
            {
                expMessage += " The associated exception message is as follows: " + exp.InnerException.Message;
            }
            xmlOut = Utilities.generateXML(expMessage);
        }

		if (customLogger.serviceLogging)
        {
            customLogger.buildLogmessage("Exiting " + serviceName + " response in JSONServiceEndpoint.aspx", new Dictionary<object, object> { { "xmlOut", xmlOut.OuterXml } });
        }
        
        try
        {
            if (xmlOut.FirstChild.SelectSingleNode("./context") != null)
            {
                XmlNode contextNode = xmlOut.SelectSingleNode(".//context");
                transformXml(contextNode);
            }
            if (customLogger.serviceLogging)
			{
				customLogger.buildLogmessage("Before converting service response XML to JSON", new Dictionary<object, object> { { "xmlOut", xmlOut.OuterXml } });
			}
            XmlDocument responseXml = new XmlDocument();
            if (isOutListMentioned && xmlOut.FirstChild.SelectSingleNode("./context") != null)
            {
                /**
                 * Note: The below logic currently handled for list segment under context/simple segment; if expected list segment is under
                 * list segment (parent list) then response would be improper.
                 */
                responseXml.InnerXml = "<document/>";
                foreach (XmlNode node in xmlOut.FirstChild.SelectNodes("./" + outputListpath))
                {
                    XmlNode tempNode = responseXml.FirstChild.OwnerDocument.CreateElement("temp");
                    tempNode.InnerXml = node.OuterXml;
                    responseXml.FirstChild.AppendChild(tempNode.FirstChild);
                }
                //Newtonsoft.Json creates array of elements only if the element is repeated in the given XML document.
                //In case the list segment has only one record then only one element node will be available in the 
                //source XML document. In such situation 'JsonConvert' class doesn't creates an array for the value since 
                //the class unaware whether to create array or not. In this situation, custom XML attribute can be added to force a JSON array to be created.
                //i.e., json:Array='true'
                if (xmlOut.FirstChild.SelectNodes("./" + outputListpath).Count == 1)
                {
                    XmlAttribute attr = responseXml.CreateAttribute("json", "Array", "http://james.newtonking.com/projects/json");
                    attr.InnerText = "true";
                    XmlElement element = (XmlElement) responseXml.DocumentElement.FirstChild;
                    element.SetAttributeNode(attr);
                }                
                serviceOutputJSON = Newtonsoft.Json.JsonConvert.SerializeObject(responseXml, Newtonsoft.Json.Formatting.None);
            
                //To handle a case where no data retured by the service for the given outputListpath
                if (serviceOutputJSON == "{\"document\":null}")
                    serviceOutputJSON = "[]"; //refers an empty output list
			}
            else
            {
                serviceOutputJSON = Newtonsoft.Json.JsonConvert.SerializeObject(xmlOut, Newtonsoft.Json.Formatting.None);
            }
            
        }
        catch (Exception exp)
        {
            serviceOutputJSON = @"{""ApplicationException"":{""errorNumber"":"""",""errorDescription"":""" + exp.Message +  @"""}}";
        }        
        finally
        {
            if (customLogger.serviceLogging)
            {
				customLogger.buildLogmessage("Exiting JSONServiceEndpoint.aspx for " + applicationName + "." + serviceName + "", new Dictionary<object, object> { { "serviceOutputJSON", serviceOutputJSON } });
                writeServiceTraceLog_EnterpriseLibrary(customLogger.loggerContent, CustomUtil.getELLogCategoryName(contextDataItems, applicationName));
            }
        }
        serviceEndTime = DateTime.Now.ToString("dd-MMM-yyyy hh:mm:ss.fff");

        try
        {
            /*
             * Note: 'ServiceInputJSON' and 'ServiceOutputJSON' are additionally provided for recording JSON data in 'writeAuditTrail' method.
             * To use these two params in 'writeAuditTrail' method, make appropriate changes in that method's implementation.
             */
            
            CustomUtil.writeAuditTrail(applicationName, serviceName, xmlIn, xmlOut,
                                        new Dictionary<object, object> { 
                                        { "ServiceStartTime", serviceStartTime }, { "ServiceEndTime", serviceEndTime },
                                        { "ServiceInputJSON", serviceInputJSON }, { "ServiceOutputJSON", serviceOutputJSON },
                                        { "Url", Request.Url }, { "RequestType", Request.RequestType}, { "PhysicalPath", Request.PhysicalPath }, 
                                        { "UserHostAddress", Request.UserHostAddress }, { "UserHostName", Request.UserHostName }
                                        }
                                       );
        }
        catch
        {
            /*
             * This is a 'do-nothing' catch block. This has been introduced deliberately, to catch and suppress exceptions raised from within 'writeAuditTrail' method.
             * Without this try-catch block, exceptions raised from within 'writeAuditTrail' method would get propagated to the client program (e.g. user interface)
             * that invoked this service, which is an incorrect behavior. Regardless of the success or failure of 'writeAuditTrail' method, this service has to return
             * the original service response to the client program.
             */
        }
        
        /*
         * The following try-catch block is a stop-gap fix to forcibly return unnamed JSON array. This fix strips off the array name and returns the array contents alone.
         * This fix needs to be removed later, once the user interfaces are corrected to receive and bind named JSON arrays.
         */
        try
        {
            if (isOutListMentioned && xmlOut.FirstChild.SelectSingleNode("./context") != null && serviceOutputJSON != "[]")
            {
                if (serviceOutputJSON.IndexOf("[") != -1)
                {
                    serviceOutputJSON = serviceOutputJSON.Substring(serviceOutputJSON.IndexOf("["), (serviceOutputJSON.Length - serviceOutputJSON.IndexOf("[") - 2));
                }
            }
        }
        catch (Exception exp)
        {
            serviceOutputJSON = @"{""ApplicationException"":{""errorNumber"":"""",""errorDescription"":""" + exp.Message + @"""}}";
        }
        
        Response.ContentType = "application/json";
        Response.Write(serviceOutputJSON.Replace(@"\""", @"""").Replace(@"""{", "{").Replace(@"}""", "}"));
        xmlOut = null;
    }

    //FUNCTION TO TRANSFORM XML
    private void transformXml(XmlNode parentNode)
    {
        foreach (XmlNode childNode in parentNode.ChildNodes)
        {
            if (childNode.ChildNodes.Count > 0 && childNode.FirstChild is System.Xml.XmlText) //Leaf node
            {
                if (childNode.Name.Contains("_xml") || childNode.Name.Contains("_json"))
                {
                    childNode.InnerXml = childNode.InnerText.Replace("&amp;", "&").Replace("&", "&amp;");
                    
                    for (int nodei = 0; nodei < childNode.ChildNodes.Count; nodei++)
                    {
                        XmlNode node = parentNode.OwnerDocument.CreateElement("temp");
                        node.InnerXml = childNode.ChildNodes[nodei].OuterXml;
                        parentNode.AppendChild(node.FirstChild);
                    }
                    parentNode.RemoveChild(childNode);
                }
            }
            else if (childNode.HasChildNodes)
            {
                transformXml(childNode);
            }
        }
    }

    //FUNCTION TO WRITE SERVICE TRACE LOG USING ENTERPRISE LIBRARY LOGGING 
    /*
     * NOTE: 
     * Uncomment the function body whenever the target application has generated with 'Inject logging code' during code 
     * generation. It requires, 'Microsoft.Practices.EnterpriseLibrary.Logging.dll' and its dependency DLLs are deployed 
     * in bin directory. Similarly, when 'Microsoft.Practices.EnterpriseLibrary.Logging.dll' and its dependency DLLs are 
     * not deployed in bin directory or deleted from bin directory, comment the function body.
     */
    private void writeServiceTraceLog_EnterpriseLibrary(string loggerContent, string logCategoryName)
    {
        //Microsoft.Practices.EnterpriseLibrary.Logging.Logger.Write(loggerContent, logCategoryName);
    }
</script>