@echo off
setlocal enabledelayedexpansion
set iis_site_name=%1
set iis_site_port_no=%2
set site_with_path=%3
set cvs_site_name=%4
set cvs_site_port_no=%5
set cvs_site_with_path=%6
set cvs_need=%7
set create_cvs_Site=0
echo "Site name : %iis_site_name%"
echo "port no : %iis_site_port_no%"
echo "site path : %site_with_path%"
echo "CVS site name : %cvs_site_name%"
echo "CVS port no : %cvs_site_port_no%"
echo "CVS site path : %cvs_site_with_path%"
echo "CVS need : %cvs_need%"


REM check cvs site already exist
if not exist "%cvs_site_with_path%" set create_cvs_Site=1

REM Checking website already exist
if exist "%site_with_path%" GOTO website_folder_exists_error

cd "%SYSTEMROOT%\System32\inetsrv"

REM CVS site part
if !cvs_need! EQU 1 ( REM if cvs needed
if !create_cvs_Site! EQU 1 (
echo "Creating CVS applicationPool"
echo "appcmd add apppool /name:%cvs_site_name% /enable32BitAppOnWin64:true"
appcmd add apppool /name:%cvs_site_name% /enable32BitAppOnWin64:true
if !ERRORLEVEL! NEQ 0 GOTO cvs_applicationPool_creation_error

echo "Creating CVS folder"
echo "mkdir %cvs_site_with_path%"
mkdir %cvs_site_with_path%
if !ERRORLEVEL! NEQ 0 GOTO cvs_directory_creation_error

echo "Creating CVS site in IIS"
echo "appcmd add site /name:%cvs_site_name% /bindings:http/*:%cvs_site_port_no%: /physicalPath:%cvs_site_with_path%"
appcmd add site /name:%cvs_site_name% /bindings:http/*:%cvs_site_port_no%: /physicalPath:%cvs_site_with_path%
if !ERRORLEVEL! NEQ 0 GOTO cvs_site_creation_error

echo "Pointing applicationPool to CVS website"
echo "appcmd set site /site.name:%cvs_site_name% /[path='/'].applicationPool:%cvs_site_name%"
appcmd set site /site.name:%cvs_site_name% /[path='/'].applicationPool:%cvs_site_name%
if !ERRORLEVEL! NEQ 0 GOTO cvs_applicationPool_pointing_error

echo "Opening CVS port in firewall"
echo "netsh advfirewall firewall add rule name="IIS Ports" protocol=TCP dir=in localport=%cvs_site_port_no% action=allow"
netsh advfirewall firewall add rule name="IIS Ports" protocol=TCP dir=in localport=%cvs_site_port_no% action=allow
if !ERRORLEVEL! NEQ 0 GOTO cvs_port_opening_error ) ) 
REM CVS site part end
goto create_website

REM website site part
:create_website
echo "Creating website applicationPool"
echo "appcmd add apppool /name:%iis_site_name% /enable32BitAppOnWin64:true"
appcmd add apppool /name:%iis_site_name% /enable32BitAppOnWin64:true
if !ERRORLEVEL! NEQ 0 GOTO applicationPool_creation_error

echo "Creating website folder"
echo "mkdir %site_with_path%"
mkdir %site_with_path%
if !ERRORLEVEL! NEQ 0 GOTO directory_creation_error

echo "Creating website"
echo "appcmd add site /name:%iis_site_name% /bindings:http/*:%iis_site_port_no%: /physicalPath:%site_with_path%"
appcmd add site /name:%iis_site_name% /bindings:http/*:%iis_site_port_no%: /physicalPath:%site_with_path%
if !ERRORLEVEL! NEQ 0 GOTO iis_site_creation_error

echo "Pointing applicationPool to website"
echo "appcmd set site /site.name:%iis_site_name% /[path='/'].applicationPool:%iis_site_name%"
appcmd set site /site.name:%iis_site_name% /[path='/'].applicationPool:%iis_site_name%
if !ERRORLEVEL! NEQ 0 GOTO applicationPool_pointing_error

echo "Opening website port in firewall"
echo "netsh advfirewall firewall add rule name="IIS Ports" protocol=TCP dir=in localport=%iis_site_port_no% action=allow"
netsh advfirewall firewall add rule name="IIS Ports" protocol=TCP dir=in localport=%iis_site_port_no% action=allow
if !ERRORLEVEL! NEQ 0 GOTO port_opening_error
if !ERRORLEVEL! EQU 0 GOTO success
REM website site part end



:website_folder_exists_error
echo "Website folder already exists in target environment"
exit /b 1

:directory_creation_error
echo "Error in creating website folder"
exit /b 1

:applicationPool_creation_error
echo "Error in creating applicationPool"
exit /b 1

:iis_site_creation_error
echo "Error in creating IIS site"
exit /b 1

:applicationPool_pointing_error
echo "Error in pointing IIS site to applicationPool"
exit /b 1

:port_opening_error
echo "Error in opening port in firewall"
exit /b 1

:cvs_directory_creation_error
echo "CVS folder already exists in target environment"
exit /b 1

:cvs_applicationPool_creation_error
echo "Error in creating CVS applicationPool"
exit /b 1

:cvs_site_creation_error
echo "Error in creating CVS site in IIS"
exit /b 1

:cvs_applicationPool_pointing_error
echo "Error in pointing CVS site to applicationPool"
exit /b 1

:cvs_port_opening_error
echo "Error in opening CVS port in firewall"
exit /b 1

:success
echo "Sites created successfully"
exit /b 0