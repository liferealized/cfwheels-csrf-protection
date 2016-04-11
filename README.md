# CFWheels CSRF Protection Plugin

Out of the box, CFWheels applications have a Cross-Site Request Forgery (CSRF) security vulnerability. OWASP
has an excellent [overview of CSRF][1] if you're unfamiliar with this vulnerability (or need a refresher).

This plugin helps protect against CSRF attacks by authorizing all `POST` requests against the user's session.
All `POST` requests must contain an authenticity token either via a field named `authenticityToken` (usually
provided as a hidden form field) or a request header named `X-CSRF-Token` (usually for AJAX `POST`s). `POST`ed
requests not containing this authenticity token will throw an exception named
`Wheels.InvalidAuthenticityToken` by default.

## Setup

Install this plugin by grabbing the zip file from the latest release in the [Releases tab][2] on GitHub,
placing it in the `plugins` folder of your CFWheels application, and reloading your app.

Next, add a call to the `protectFromForgery` controller intializer in your base
`controllers/Controller.cfc`:

```coldfusion
<cffunction name="init">
	<cfset protectFromForgery()>
</cffunction>
```

And then add a call to the `csrfMetaTags` view helper to your layout's `<head>` section:

```coldfusion
<cfoutput>

<head>
	#csrfMetaTags()#
</head>

</cfoutput>
```

Your application is now CSRF-protected, given that you're good with the _Prerequisites_ listed below.

If you have an API, you'll probably want to read the _Skipping CSRF Protection for APIs_ section later in
this README.

## Public Methods

`protectFromForgery([string with, string only, string except])`<br />
Call this in a controller's `init` method (usually in the base `controllers/Controller.cfc`) to setup CSRF
protection. The optional `with` argument accepts values of `error` (default), which raises a
`Wheels.InvalidAuthenticityToken` error on failed authenticity token verification, and `abort`, which aborts
requests with a failed authenticity token silently. The `only` and `except` arguments work similarly to the
corresponding ones for the CFWheels `filters` method.

`csrfMetaTags()`<br />
Include this in your layouts' `<head>` sections to include `meta` tags containing the authenticity token for
use by JavaScript AJAX requests. (See the _Open Issue: AJAX Calls_ section below for more information.)

`authenticityTokenField()`<br />
If you need to manually place the `authenticityToken` hidden field in your own form, use this form helper to
do so. (See the _Prerequisites_ section below for more information about this.)

## Prerequisites

This plugin assumes that your CFWheels application only changes data within your application via HTTP `POST`,
`PUT`, `PATCH`, and `DELETE` requests. The plugin protects all of these types of requests (excluding `GET` and
`HEAD` requests).

At the time of this writing, web browser clients will only reliably perform `POST` requests, so if your
CFWheels forms are mutating data only via `POST` requests, you're good to go. If not, then you'll need to
double-check this before patching up your application with this plugin.

### Step 1: Protect the controllers

First, you need to make sure that all controller actions that change data require a `POST` request.

There are a couple ways to accomplish this:

1) Use the excellent [ColdRoute plugin][3]'s resource handling, and configure all of your one-off routes
using the HTTP verb-based helpers:

```coldfusion
<cfscript>
drawRoutes()
	// Resources already provide HTTP verb checks for actions that likely mutate data.
	// This protects your app from CSRF.
	.namespace("admin")
		.resources("users")
		.resources("roles")
		.resources("permissions")
	.end()

	// Here, we make sure we're using HTTP verb-based routing, which also protects your app from CSRF.
	.get(name="login", controller="sessions", action="new")
	.post(name="authenticate", controller="sessions", action="create")
	.get(name="forgotPassword", controller="passwords", action="edit")
	.put(name="sendPassword", controller="passwords", action="update")
.end()
</cfscript>
```

2) Use the CFWheels `verifies` method to ensure that a `POST` verb is used to access controller actions that
mutate data.

Here is an example where the `create`, `update`, and `delete` methods are changing data in the database, and
thus need to be protected. However, the `index`, `new`, and `edit` methods don't need any sort of protection.

```coldfusion
<cfcomponent extends="Controller">
	<cffunction name="init">
		<cfset super.init()>
		<cfset verifies(post=true, only="create,update,delete")>
	</cffunction>

	<cffunction name="index">
	</cffunction>

	<cffunction name="new">
	</cffunction>

	<cffunction name="create">
	</cffunction>

	<cffunction name="edit">
	</cffunction>

	<cffunction name="update">
	</cffunction>

	<cffunction name="delete">
	</cffunction>
</cfcomponent>
```

### Step 2: Make sure HTML forms are `POST`ing the data

An example of good practice is using `startFormTag`'s default value for `method` whenever you're changing data
through a form:

```coldfusion
<cfoutput>

<!-- The default is method="post" -->
#startFormTag(route="users")#
	<!--- Etc. --->
#endFormTag()#

<!-- Or if you're outside of CFWheels helpers -->
<form action="#urlFor(route='users')#" method="post">
	<!-- Etc. -->
</form>

</cfoutput>
```

Appropriately, this plugin adds a hidden field within all of your `startFormTag`-based forms with an
`authenticityToken` that proves that a real human being is posting the form as they should be:

```html
<input type="hidden" name="authenticityToken" value="cxRbrHAnwpG0Ki9vTYW4yg==">
```

NOTE: If you do have any hard-coded `<form>` tags, you'll want to manually add a call to this plugin's
`authenticityTokenField` method:

```coldfusion
<cfoutput>

<form action="#urlFor(route='users')#" method="post">
	#authenticityTokenField()#
	<!-- Etc. -->
</form>

</cfoutput>
```

(If you're using `startFormTag`, no need to worry about this: it's taken care of for you.)

## Skipping CSRF Protection for APIs

You'll likely not want CSRF protection enabled for API endpoints (which should be authenticated in some other
way like OAuth and/or via a token system anyway). You can avoid the CSRF protection by either not including it
in the API's inheritance chain or by using `protectFromForgery`'s `except` argument.

Here is an example of how to avoid `protectFromForgery` if you have your API mixed in with a traditional HTML
app:

```coldfusion
<!-- controllers/Controller.cfc -->
<cfcomponent extends="Wheels">
	<cffunction name="init">
		<cfargument name="includeForgeryProtection" type="boolean" required="false" default="true">

		<cfif arguments.includeForgeryProtection>
			<cfset protectFromForgery()>
		</cfif>
	</cffunction>
</cfcomponent>

<!-- controllers/Api.cfc -->
<cfcomponent extends="Controller">
	<cffunction name="init">
		<!-- Turn off forgery protection for all API endpoints that extend this controller -->
		<cfset super.init(includeForgeryProtection=false)>

		<cfset provides("json")>
	</cffunction>
</cfcomponent>

<!-- controllers/ApiUsers.cfc -->
<cfcomponent extends="Api">
	<cffunction name="init">
		<cfset super.init()>
	</cffunction>

	<cffunction name="create">
	</cffunction>
</cfcomponent>
```

## Changing the Failed Authenticity Token Verification Strategy Per Controller

Let's say that you want to raise an error for most authenticity token failures but have a particularly
chatty controller that you would just like to fail silently via `abort`.

You can work with the inheritance chain similarly to what I prescribed in the _Skipping CSRF Protection for
APIs_ section above (or even used in combination with that strategy):

```coldfusion
<!-- controllers/Controller.cfc -->
<cfcomponent extends="Wheels">
	<cffunction name="init">
		<cfargument name="protectFromForgeryWith" type="string" required="false" default="error">
		<cfset protectFromForgery(with=arguments.protectFromForgeryWith)>
	</cffunction>
</cfcomponent>

<!-- controllers/Comments.cfc -->
<cfcomponent extends="Controller">
	<cffunction name="init">
		<!-- Don't throw an error for failed verification only for this controller. -->
		<cfset super.init(protectFromForgeryWith="abort")>
	</cffunction>
</cfcomponent>

<!-- controllers/Sessions.cfc -->
<cfcomponent extends="Controller">
	<cffunction name="init">
		<!-- This controller relies on the default behavior. -->
		<cfset super.init()>
	</cffunction>
</cfcomponent>
```

## Open Issue: AJAX Calls

JavaScript calls that use AJAX to `POST` to your CFWheels app may get tripped up by CSRF Protection.

jQuery or whatever you're using for AJAX should be configured to read the `meta` tags generated by the
`csrfMetaTags` helper, and then post its value via an HTTP header named `X-CSRF-Token`.

Here is an example of configuring jQuery to do this for all AJAX calls:

```javascript
define(['jquery'], function ($) {
  var token = $('meta[name="csrf-token"]').attr('content');

  $.ajaxSetup({
    beforeSend: function (xhr) {
      xhr.setRequestHeader('X-CSRF-Token', token);
    }
  });

  return token; 
});
```

## Building the plugin release

Follow these steps:

1.  Update `build.sh` to have the correct version number for the release.
2.  Run `sh build.sh`

The zip file should appear containing a releaseable CFWheels plugin named `CsrfProtection-[VERSION].zip`.

## License

The MIT License (MIT)

Copyright (c) 2016 Liquifusion Studios


[1]: https://www.owasp.org/index.php/Cross-Site_Request_Forgery_%28CSRF%29
[2]: https://github.com/liquifusion/cfwheels-csrf-protection/releases
[3]: https://github.com/dhumphreys/cfwheels-coldroute
