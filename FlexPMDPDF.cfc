<cfcomponent output="false">
	
	<!--- 
		****************************************************************************************
		* FlexPMDPDF version 1.0															   *
		****************************************************************************************
		* Description																		   *
		****************************************************************************************
		* This program will take a pmd xml file output by Flex PMD and create a PDF report with*
		* several formatting and filtering options.  You can choose to group by rule, file or  *
		* priority and you can further filter the rule and file groupings by priority.  This   *
		* program requires Adobe ColdFusion 8 or later.										   *
		****************************************************************************************
		* License																			   *
		****************************************************************************************
		*  It's free! Use it, modify it, but if you fuck something up, I'm not liable!         *
		****************************************************************************************
		* Other Stuff																		   *
		****************************************************************************************
		* Author: Kevin Schmidt ( kevin.schmidt@othersidellc.com )							   *
		* Date Created: 10.13.2009															   *
		* Last Modified: 10.15.2009															   *
		* Modifications:																	   *
		*	10.15.2009 - Initial release													   *
		****************************************************************************************
		* Call Structure																	   *
		* 	generateReport( pathToPMDFile, pathToWritePDF, reportType, priorityList )		   *
		*	- pathToPMDFile ( required ): This is the full path to the PMD XML file 		   *
		* 	- pathToWritePDF ( required ): The full path to where you want the PDF report      *
		*		written and the name of the file.  It will overwrite an existing file.         *
		*	- reportType ( required ): The type of report 									   *
		*		Valid options are:															   *
		*		 - "byFile"																	   *
		*		 - "byRule"																	   *	
		*		 - "byPriority"																   *
		*	- priorityList ( optional ): This comma delimmited list is filter for the priority *
		*		of the violations.															   * 
		*		Valid options are:															   *
		*		 - "ERRORS"																	   *
		*		 - "WARNINGS"																   *
		*		 - "INFO"																	   *
		****************************************************************************************
		* Example call																		   *
		****************************************************************************************
		* 	<cfset flexPMDPDF = CreateObject( "component", "FlexPMDPDF" ) />				   *
		*	<cfset reportByRule = 															   *
		*		flexPMDPDF.generateReport( 													   *
		*			"C:\ColdFusion9\wwwroot\FlexPMDPDF\pmd.xml",							   *
		*			"C:\ColdFusion9\wwwroot\FlexPMDPDF\pmd.pdf", 							   *
		*			"byRule",																   *
		*			"ERRORS,WARNINGS") 														   *
		*			/>																		   *
		****************************************************************************************
	--->
	
	
	<cffunction name="generateReport" access="public" returntype="boolean">
		<cfargument name="pathToPMD" 	required="true" 	type="string" />
		<cfargument name="pathToPDF"	required="true" 	type="string" />
		<cfargument name="reportType" 	required="true" 	type="string" />
		<cfargument name="priorityList" required="false" 	type="string" default="" />
		
		<!--- CREATE LOCAL VARIABLES --->
		
		<!--- PMD VARIABLES --->
		<!--- VALUE TO HOLD FILE TO BE READ IN --->
		<cfset var pmdFile 			= "" />
		
		<!--- VARIABLES TO HOLD DATA FROM THE PMD FILE --->
		<cfset var pmdFiles 				= "" />
		<cfset var pmdRules					= "" />
		<cfset var pmdViolations 			= "" />
		<cfset var pmdViolationsP1 			= "" />
		<cfset var pmdViolationsP3 			= "" />
		<cfset var pmdViolationsP5 			= "" />
		
		<!--- ARRAY TO HOLD ALL THE VIOLATION OBJECTS --->
		<cfset var pmdViolationArray 		= ArrayNew( 1 ) />
		<!--- STRUCTURE TO HOLD MAIN DATA --->
		<cfset var pmdViolationObject 		= "" />

		<!--- OTHER VARIABLES --->
		<cfset var i 				= "" />
		<cfset var j 				= "" />
		<cfset var priorityFilter 	= "" />
		
		
		
		<!--- DOES THE FILE EXIST, IF NOT THROW AN ERROR --->
		<cfif NOT FileExists( arguments.pathToPMD )>
			<cfthrow message="The PMD file you specified can not be found!" />
		</cfif>
		
		<!--- FILE DOES EXIST, READ IT IN --->
		<cffile 
			action="read" 
			file="#arguments.pathToPMD#" 
			variable="pmdFile" 
			/>
		
	
		<cfswitch expression="#arguments.reportType#">
			<cfcase value="byFile">
				
				<!--- SEARCH THE XML FOR A LIST OF FILES WITH VIOLATIONS --->
				<cfset pmdFiles = XMLSearch( pmdFile, "/pmd/file/@name" ) />
				
				
				
				<!--- LOOP OVER THE LIST OF FILES AND GRAB VIOLATIONS FOR EACH --->
				<cfloop array="#pmdFiles#" index="i">
					<!--- SET UP THE VIOLATION OBJECT --->
					<cfset pmdViolationObject 					= StructNew() />
					
					<!--- ADD THE FILE NAME --->
					<cfset pmdViolationObject["violationType"] 	= i["XmlValue"] />
					
					<!--- CREATE ARRAY TO HOLD VIOLATION OBJECTS --->
					<cfset pmdViolationObject["violationArray"] = ArrayNew( 1 ) />
					
					<!--- GET THE VIOLATIONS FOR THIS FILE --->
					<!--- DO WE NEED TO FILTER BY PRIORITY? --->
					<cfif Len( Trim( arguments.priorityList ) )>
						<!--- CREATE THE FILTER STRING --->
						<cfset priorityFilter = buildPriorityFilter( arguments.priorityList) />
						
						<cfset pmdViolations = XMLSearch( pmdFile, "/pmd/file[@name='#i['XmlValue']#']/violation[#priorityFilter#]" ) />
						
					<cfelse>
						<cfset pmdViolations = XMLSearch( pmdFile, "/pmd/file[@name='#i['XmlValue']#']/violation" ) />
					</cfif>
					
					<cfdump var="#pmdViolations#" />
					
					<!--- LOOP OVER THE VIOLATIONS AND BUILD THE VIOLATION DETAIL OBJECT FOR EACH AND ADD TO THE ARRAY --->
					<cfloop array="#pmdViolations#" index="j">
						<cfset ArrayAppend( pmdViolationObject["violationArray"], buildViolationDetailObject( j["XmlAttributes"], j["XmlText"] ) ) />
					</cfloop>
					
					<!--- ADD THE VIOLATION DETAIL OBJECT TO THE MAIN ARRAY --->
					<cfset ArrayAppend( pmdViolationArray, pmdViolationObject ) />
				
				</cfloop>
				<cfabort>
			</cfcase>
			
			
			<cfcase value="byRule">
				<!--- SEARCH THE XML FOR ALL THE RULES THAT WERE VIOLATED --->
				<cfset pmdRules = XMLSearch( pmdFile, "/pmd/file/violation/@rule" ) />
				
				<!--- THIS IS A HACK AS I DON'T SEE COLDFUSION SUPPORTING THE DISTINCT-VALUES FUNCTION OF XPATH --->
				<cfset pmdRules = removeDuplicateRules( pmdRules ) />
				
								
				<!--- LOOP OVER THE RULES AND GRAB ALL THE VIOLATIONS FOR THAT RULE --->
				<cfloop array="#pmdRules#" index="i">
					<!--- SET UP THE VIOLATION OBJECT --->
					<cfset pmdViolationObject 					= StructNew() />
					
					<!--- ADD THE RULE NAME --->
					<cfset pmdViolationObject["violationType"] 	= i["XmlValue"] />
					
					<!--- CREATE ARRAY TO HOLD VIOLATION OBJECTS --->
					<cfset pmdViolationObject["violationArray"] = ArrayNew( 1 ) />
					
					<!--- GET THE VIOLATIONS FOR THIS FILE --->
					<!--- DO WE NEED TO FILTER BY PRIORITY? --->
					<cfif Len( Trim( arguments.priorityList ) )>
						<!--- CREATE THE FILTER STRING --->
						<cfset priorityFilter = buildPriorityFilter( arguments.priorityList) />
					
						<cfset pmdViolations = XMLSearch( pmdFile, "/pmd/file/violation[@rule='#i['XmlValue']#' and (#priorityFilter#)]" ) />
					<cfelse>
						<cfset pmdViolations = XMLSearch( pmdFile, "/pmd/file/violation[@rule='#i['XmlValue']#']" ) />
					</cfif>
					
					
					<!--- LOOP OVER THE VIOLATIONS AND BUILD THE VIOLATION DETAIL OBJECT FOR EACH AND ADD TO THE ARRAY --->
					<cfloop array="#pmdViolations#" index="j">
						<cfset ArrayAppend( pmdViolationObject["violationArray"], buildViolationDetailObject( j["XmlAttributes"], j["XmlText"] ) ) />
					</cfloop>
					
					<!--- ADD THE VIOLATION DETAIL OBJECT TO THE MAIN ARRAY --->
					<cfset ArrayAppend( pmdViolationArray, pmdViolationObject ) />
				
				</cfloop>
			</cfcase>
			
			<cfcase value="byPriority">
				<!--- GET THE ERRORS THAT WERE REQUESTED --->
				<!--- ERRORS - PRIORITY 1--->
				<cfif NOT Len( Trim( arguments.priorityList ) ) || ListFind( arguments.priorityList, "ERRORS" )>
					<cfset pmdViolationsP1 =   XMLSearch( pmdFile, "/pmd/file/violation[@priority=1]" ) />
					<cfset ArrayAppend( pmdViolationArray, buildViolationPriorityObject( pmdViolationsP1, "ERRORS") ) />
				</cfif>
				<!--- WARNINGS - PRIORITY 3 --->
				<cfif NOT Len( Trim( arguments.priorityList ) ) || ListFind( arguments.priorityList, "WARNINGS" )>
					<cfset pmdViolationsP3 =   XMLSearch( pmdFile, "/pmd/file/violation[@priority=3]" ) />
					<cfset ArrayAppend( pmdViolationArray, buildViolationPriorityObject( pmdViolationsP3, "WARNINGS") ) />
				</cfif>
				<!--- INFO - PRIORITY 5--->
				<cfif NOT Len( Trim( arguments.priorityList ) ) || ListFind( arguments.priorityList, "INFO" )>
					<cfset pmdViolationsP5 =   XMLSearch( pmdFile, "/pmd/file/violation[@priority=5]" ) />
					<cfset ArrayAppend( pmdViolationArray, buildViolationPriorityObject( pmdViolationsP5, "INFO") ) />
				</cfif>
			</cfcase>
			
			<cfdefaultcase>
				<cfthrow message="Invalid report type!" />
			</cfdefaultcase>
		</cfswitch>
		
		<!--- GENERATE THE PDF --->
		<cfset buildPDF( pmdViolationArray, arguments.reportType, arguments.pathToPDF ) />
	
		<cfreturn true />
	
	</cffunction>
	
	
	<!--- *********************************************************************************** --->
	<!--- * H.E.L.P.eR FUNCTIONS ( Get that, without Google, see me, I owe you a beer!	    * --->
	<!--- *********************************************************************************** --->
	
	<cffunction name="buildPriorityFilter" access="private" returntype="string">
		<cfargument name="priorityList" required="true" type="string" />
		
		<cfset var priorityFilter = "" />
		<cfset var i = "" />
		
		<cfloop list="#arguments.priorityList#" index="i">
			<!--- IF IT IS NOT VALID, IT WILL THROW AN ERROR --->
			<cfif isValidPriority( i )>
				<!--- IS THIS THE FIRST? --->
				<cfif priorityFilter EQ "">
					<cfset priorityFilter = "@priority=" & getPriorityNumber( i ) />
				<cfelse>
					<cfset priorityFilter = priorityFilter & " or @priority=" & getPriorityNumber( i ) />
				</cfif>
			</cfif>
		</cfloop>
		
		<cfreturn priorityFilter />
	
	</cffunction> 
	
	<cffunction name="buildViolationPriorityObject" access="private" returntype="struct">
		<cfargument name="violationPriorityArray" 	required="true" type="array" />
		<cfargument name="priority"					required="true" type="string" />
		
		<!--- SET UP THE VIOLATION OBJECT --->
		<cfset var pmdViolationObject 	= StructNew() />
		<cfset var i 					= "" />
					
		<!--- ADD THE RULE NAME --->
		<cfset pmdViolationObject["violationType"] 	= arguments.priority />
		<cfset pmdViolationObject["violationArray"] = ArrayNew( 1 ) />
		
		<!--- LOOP OVER THE VIOLATIONS AND BUILD THE VIOLATION DETAIL OBJECT FOR EACH AND ADD TO THE ARRAY --->
		<cfloop array="#arguments.violationPriorityArray#" index="i">
			<cfset ArrayAppend( pmdViolationObject["violationArray"], buildViolationDetailObject( i["XmlAttributes"], i["XmlText"] ) ) />
		</cfloop>
		
		<cfreturn pmdViolationObject />
	</cffunction>
	
	<cffunction name="buildViolationDetailObject" access="private" returntype="struct"> 
		<cfargument name="violationDetailData" 	required="true" type="struct" />
		<cfargument name="violationMessage" 	required="true" type="string" />
		
		<cfset var violationDetailObject 				= StructNew() />
		
		<cfset violationDetailObject["beginLine"] 		= arguments.violationDetailData.beginline />
		<cfset violationDetailObject["beginColumn"] 	= arguments.violationDetailData.begincolumn />
		
		<cfset violationDetailObject["endLine"] 		= arguments.violationDetailData.endline />
		<cfset violationDetailObject["endColumn"] 		= arguments.violationDetailData.endcolumn />
		
		<cfset violationDetailObject["class"] 			= arguments.violationDetailData.class />
		<cfset violationDetailObject["package"] 		= arguments.violationDetailData.package />
		
		<cfset violationDetailObject["priority"] 		= getPriorityString( arguments.violationDetailData.priority ) />
		
		<cfset violationDetailObject["rule"] 			= arguments.violationDetailData.rule />
		<cfset violationDetailObject["ruleSet"] 		= arguments.violationDetailData.ruleSet />
		
		<cfset violationDetailObject["message"] 		= arguments.violationMessage />
		
		<cfreturn violationDetailObject />
		
	</cffunction>
	
	<cffunction name="buildPDF" access="private" returntype="boolean">
		<cfargument name="violationData" 	required="true" type="array" />
		<cfargument name="reportType"		required="true" type="string" />
		<cfargument name="pathToPDF"		required="true" type="string" />
	
		<cfset var reportTypeForDisplay = getReportType( arguments.reportType ) />
		<cfset var i = "" />
		<cfset var j = "" />
		
		<cfdocument 
			format="PDF" 
			filename="#arguments.pathToPDF#" 
			overwrite="true"
			>
			<cfoutput>
				<cfdocumentitem type="footer">
					<font face="arial" size="2">
					  Page #cfdocument.currentpagenumber# of #cfdocument.totalpagecount#
					</font>	
				</cfdocumentitem>
				
				<br/><br/><br/>
				<font face="arial" size="4">
					FlexPMD REPORT BY #reportTypeForDisplay# <br/>
					Report Generated On: #DateFormat( now(), "mm/dd/yyyy" )# - #TimeFormat( now(), "hh:mm TT" )#
					<br/><br/>
				</font>
				
				<cfdocumentitem type="pagebreak" />
				
				
				<cfloop array="#arguments.violationData#" index="i">
					
					<font face="arial" size="4">
						#i["violationType"]#
					</font>
					<br/><br/>
					<table width="700">
						<tr>
							<td bgcolor="##DAE1E9" valign="middle" width="20">
								<font size="1" face="arial">
									PRIORITY
								</font>
							</td>
							
							<td bgcolor="##DAE1E9" valign="middle" width="10">
								<font size="1" face="arial">
									LINE
								</font>
							</td>
							<td bgcolor="##DAE1E9" valign="middle">
								<font size="1" face="arial">
									FILE
								</font>
							</td>
							
							<td bgcolor="##DAE1E9" valign="middle">
								<font size="1" face="arial">
									MESSAGE
								</font>
							</td>
						</tr>
					
					
						<cfloop array="#i['violationArray']#" index="j">
							<tr>
								<td valign="middle" width="20">
									<font size="1" face="arial">
										#j["priority"]#
									</font>
								</td>
								
								<td valign="middle" width="10">
									<font size="1" face="arial">
										#j["beginLine"]#
									</font>
								</td>
								<td valign="middle">
									<font size="1" face="arial">
										#j["package"]# - #j["class"]#
									</font>
								</td>
								
								<td valign="middle">
									<font size="1" face="arial">
										#j["message"]#
									</font>
								</td>
							</tr>
						</cfloop>
					</table>
					
					<br/><br/>
					
				</cfloop>	
			</cfoutput>	
			
		</cfdocument>
	
		<cfreturn true />
	</cffunction>
	
	<!--- LOOK UP FUNCTIONS --->
	<cffunction name="getPriorityString" access="private" returntype="string">
		<cfargument name="priority" required="true" type="numeric" />
		
		<cfswitch expression="#arguments.priority#">
			<cfcase value="1">
				<cfreturn "ERROR" />
			</cfcase>
			
			<cfcase value="3">
				<cfreturn "WARNING" />
			</cfcase>
		
			<cfcase value="5">
				<cfreturn "INFO" />
			</cfcase>
			
			<cfdefaultcase>
				<cfreturn "UNKNOWN PRIORITY" />
			</cfdefaultcase>
		</cfswitch>
	</cffunction>
	
	<cffunction name="getPriorityNumber" access="private" returntype="numeric">
		<cfargument name="priority" required="true" type="string" />
		
		<cfswitch expression="#arguments.priority#">
			<cfcase value="ERRORS">
				<cfreturn 1 />
			</cfcase>
			
			<cfcase value="WARNINGS">
				<cfreturn 3 />
			</cfcase>
		
			<cfcase value="INFO">
				<cfreturn 5 />
			</cfcase>
		</cfswitch>
	</cffunction>
	
	
	<cffunction name="getReportType" access="private" returntype="string">
		<cfargument name="reportType" required="true" type="string" />
		
		<cfswitch expression="#arguments.reportType#">
			<cfcase value="byFile">
				<cfreturn "FILE" />
			</cfcase>
			
			<cfcase value="byRule">
				<cfreturn "RULE" />
			</cfcase>
		
			<cfcase value="byPriority">
				<cfreturn "PRIORITY" />
			</cfcase>
		</cfswitch>
	</cffunction>
	
	<cffunction name="isValidPriority" access="private" returntype="boolean">
		<cfargument name="priority" required="true" type="string" />
		
		<cfset var validPriorityList = "ERRORS,WARNINGS,INFO" />
		
		<cfif ListFind( validPriorityList, arguments.priority )>
			<cfreturn true />
		<cfelse>
			<cfthrow message="Invalid Priority in the priorityList argument" />
		</cfif>
	</cffunction>
	
	<!--- HACK FUNCTION FOR NO DISTINCT_VALUES FUNCTION IN COLDFUSION XPATH --->
	<cffunction name="removeDuplicateRules" access="private" returntype="array">
		<cfargument name="pmdRules" required="true" type="array" />
		
		<cfset var rulesList 	= "" />
		<cfset var rulesArray 	= ArrayNew( 1 ) />
		<cfset var i 			= "" />
		
		<cfloop from="1" to="#ArrayLen( arguments.pmdRules )#" index="i">
			<cfif NOT ListFind( rulesList, arguments.pmdRules[i]["XmlValue"] )>
				<cfset rulesList = ListAppend( rulesList, arguments.pmdRules[i]["XmlValue"] ) />
				<cfset ArrayAppend( rulesArray, pmdRules[i] ) />
			</cfif>
		</cfloop>
		
		
		<cfreturn rulesArray />
		
	</cffunction>
	
</cfcomponent>