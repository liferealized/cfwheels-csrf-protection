<cfcomponent mixin="controller" output="false">
	<cffunction name="init" output="false">
		<cfset this.version = "1.4.0,1.4.1,1.4.2,1.4.3,1.4.4">
		<cfreturn this>
	</cffunction>

	<cfinclude template="controller/miscellaneous.cfm">
	<cfinclude template="controller/csrf.cfm">
	<cfinclude template="view/forms.cfm">
	<cfinclude template="view/csrf.cfm">
</cfcomponent>
