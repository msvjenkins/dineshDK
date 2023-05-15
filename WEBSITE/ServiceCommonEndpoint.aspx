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
        string outputListpath = "", outputListName = "";
        bool isOutListMentioned = false;
                
        if (customLogger.serviceLogging)
        {
            customLogger.buildLogmessage("Inside ServiceCommonEndpoint.aspx for " + applicationName + "." + serviceName );
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
            xmlIn.Load(Request.InputStream);

			if (customLogger.serviceLogging)
            {
                customLogger.buildLogmessage("Service request", new Dictionary<object, object> { { "xmlIn", xmlIn.OuterXml } });
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
                    methodParams = new Object[] { xmlIn, xmlOut };
                                        
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
            customLogger.buildLogmessage("Service response", new Dictionary<object, object> { { "xmlOut", xmlOut.OuterXml } });
        }
        
        try
        {
            if (xmlOut.FirstChild.SelectSingleNode("./context") != null)
            {
                if (customLogger.serviceLogging)
                {
                    customLogger.buildLogmessage("Before transforming service response XML", new Dictionary<object, object> { { "xmlOut", xmlOut.OuterXml } });
                }
                XmlNode contextNode = xmlOut.SelectSingleNode(".//context");
                transformXml(contextNode);
                if (customLogger.serviceLogging)
                {
                    customLogger.buildLogmessage("After transformed service response XML", new Dictionary<object, object> { { "xmlOut", xmlOut.OuterXml } });
                }
            }
            
            if (isOutListMentioned && xmlOut.FirstChild.SelectSingleNode("./context") != null)
            {
                /**
                 * Note: The below logic currently handled for list segment under context/simple segment; if expected list segment is under
                 * list segment (parent list) then response would be improper.
                 */
                if (customLogger.serviceLogging)
                {
                    customLogger.buildLogmessage("Service response XML (before processing outputlist - '" + outputListName + "')", new Dictionary<object, object> { { "xmlOut", xmlOut.OuterXml } });
                }
                
                XmlDocument responseXml = new XmlDocument();
                responseXml.InnerXml = "<document/>";
                foreach (XmlNode node in xmlOut.FirstChild.SelectNodes("./" + outputListpath))
                {
                    responseXml.FirstChild.AppendChild(responseXml.FirstChild.OwnerDocument.ImportNode(node, true));
                }
                xmlOut = responseXml;
                
                if (customLogger.serviceLogging)
                {
                    customLogger.buildLogmessage("Service response XML (after processed outputlist - '" + outputListName + "')", new Dictionary<object, object> { { "xmlOut", xmlOut.OuterXml } });
                }
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
        finally
        {
            if (customLogger.serviceLogging)
            {
                customLogger.buildLogmessage("Exiting ServiceCommonEndpoint.aspx for " + applicationName + "." + serviceName + "", new Dictionary<object, object> { { "service response", xmlOut } });
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
                                        { "ServiceRequest", xmlIn }, { "ServiceResponse", xmlOut },
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
        Response.ContentType = "text/xml";
        Response.Write(xmlOut.OuterXml);
        xmlOut = null;
    }

    //FUNCTION TO TRANSFORM XML
    private void transformXml(XmlNode parentNode)
    {
        foreach (XmlNode childNode in parentNode.ChildNodes)
        {
            if (childNode.ChildNodes.Count > 0 && childNode.FirstChild is System.Xml.XmlText) //Leaf node
            {
                if (childNode.Name.Contains("_xml"))
                {
                    childNode.InnerXml = childNode.InnerText.Replace("&amp;", "&").Replace("&", "&amp;");
                    for (int nodei = 0; nodei < childNode.ChildNodes.Count; nodei++)
                    {
                        parentNode.AppendChild(parentNode.OwnerDocument.ImportNode(childNode.ChildNodes[nodei], true));
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