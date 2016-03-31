<cffunction name="protectFromForgery" hint="Controller initializer for setting up CSRF protection in the controller. Call this method within a controller's `init` method, preferrably the base `Controller.cfc` file to protect the entire application." output="false">
	<cfargument name="with" type="string" required="false" default="exception" hint="How to handle invalid authenticity token checks. Valid values are `error` (throws a `Wheels.InvalidAuthenticityToken` error) and `abort` (aborts the request silently and sends a blank response to the client).">
	<cfargument name="only" type="string" required="false" default="" hint="List of actions that this check should only run on. Leave blank for all.">
	<cfargument name="except" type="string" required="false" default="" hint="List of actions that this check should be omitted from running on. Leave blank for no exceptions.">
	<cfscript>
		// Store `with` setting for this controller in `application` scope for later use.
		variables.$class.csrf.type = arguments.with;

		// Initialize filters.
		filters(
			argumentCollection=arguments,
			through="$flagRequestAsProtected,$setAuthenticityToken,$verifyAuthenticityToken,$regenerateAuthenticityToken",
			type="before"
		);
	</cfscript>
</cffunction>

<cffunction name="$flagRequestAsProtected" hint="Flags this request as protected from CSRF. If the filter that triggers this method is not run, then other functionality can omit the protection." output="false">
	<cfset request.$wheels.protectedFromForgery = true>
</cffunction>

<cffunction name="$verifyAuthenticityToken" hint="Verifies CSRF token and throws an exception if verification fails." output="false">
	<cfset var loc = {}>

	<cfif not $isVerifiedRequest()>
		<cfswitch expression="#variables.$class.csrf.type#">
			<cfcase value="abort">
				<cfabort>
			</cfcase>
			<cfdefaultcase>
				<cfthrow
					message="This POSTed request was attempted without a valid authenticity token."
					type="Wheels.InvalidAuthenticityToken"
				>
			</cfdefaultcase>
		</cfswitch>
	</cfif>
</cffunction>

<cffunction name="$isVerifiedRequest" returntype="boolean" hint="Returns whether or not this request passes CSRF protection." output="false">
	<cfreturn
		isGet()
		or isHead()
		or isOptions()
		or $isAnyAuthenticityTokenValid()
	>
</cffunction>

<cffunction name="$isAnyAuthenticityTokenValid" returntype="boolean" hint="Returns whether or not `params.authenticityToken` is valid and stored based on user's session." output="false">
	<cfscript>
		var loc = {};

		if ($isRequestProtectedFromForgery() && StructKeyExists(params, "authenticityToken")) {
			if (!StructKeyExists(session, "$wheels")) {
				session.$wheels = {};
			}

			loc.isValid = StructKeyExists(session.$wheels, "authenticityToken")
				&& session.$wheels.authenticityToken == params.authenticityToken;
		}
		else {
			loc.isValid = false;
		}
	</cfscript>
	<cfreturn loc.isValid>
</cffunction>

<cffunction name="$isRequestProtectedFromForgery" returntype="boolean" hint="Returns whether or not the request has been protected from forgery." output="false">
	<cfreturn
		StructKeyExists(request.$wheels, "protectedFromForgery")
		and IsBoolean(request.$wheels.protectedFromForgery)
		and request.$wheels.protectedFromForgery
	>
</cffunction>

<cffunction name="$generateAuthenticityToken" returntype="string" hint="Generates new authenticity token based on capabilities of CFML engine." output="false">
	<!--- Cache token for entire session. --->
	<cfparam name="session.$wheels.authenticityToken" type="string" default="#GenerateSecretKey("AES")#">
	<cfreturn session.$wheels.authenticityToken>
</cffunction>

<cffunction name="$regenerateAuthenticityToken" hint="Regenerates authenticity token if request is not AJAX-based and the request is protected from forgery." output="false">
	<cfscript>
		// If valid and not AJAX-based, reset for next full-page request.
		if (!isAjax() && $isRequestProtectedFromForgery()) {
			session.$wheels.authenticityToken = GenerateSecretKey("AES");
		}
	</cfscript>
</cffunction>

<cffunction name="$setAuthenticityToken" hint="Ensures authenticity token is set at `params.authenticityToken` if it's `POST`ed or included in the `X-CSRF-Token` header." output="false">
	<cfscript>
		var loc = {};

		if ($isVerifiedRequest() && isAjax()) {
			loc.headers = GetHttpRequestData().headers;

			if (StructKeyExists(loc.headers, "X-CSRF-Token")) {
				params.authenticityToken = loc.headers["X-CSRF-Token"];
			}
		}
	</cfscript>
</cffunction>
