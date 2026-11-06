xquery version "3.1";

(:~
 : This is the place to import your own XQuery modules for either:
 :
 : 1. custom API request handling functions
 : 2. custom templating functions to be called from one of the HTML templates
 :)
module namespace dmod-vapi="http://teipublisher.com/api/dmod-vapi";

declare namespace tei="http://www.tei-c.org/ns/1.0";
(: Add your own module imports here :)
import module namespace rutil="http://e-editiones.org/roaster/util";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

import module namespace errors="http://e-editiones.org/roaster/errors";
import module namespace cutil="http://teipublisher.com/api/cache" at "./lib/api/caching.xql";
import module namespace json="http://www.json.org";
import module namespace console="http://exist-db.org/xquery/console";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace capi="http://teipublisher.com/api/collection" at "./lib/api/collection.xql";
import module namespace router="http://e-editiones.org/roaster";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace tmpl="http://e-editiones.org/xquery/templates";
import module namespace vapi="http://teipublisher.com/api/view" at "view.xql";
import module namespace dts-client="http://www.tei-c.org/tei-publisher/dts-client" at "./dts-mod/dts-client.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "../lib/util.xql";
import module namespace page="http://teipublisher.com/ns/templates/page" at "../../templates/page.xqm";

import module namespace custom-config="http://www.tei-c.org/tei-simple/custom-config" at "custom-config.xqm";
(:~
 : Keep this. This function does the actual lookup in the imported modules.
 :)
declare function dmod-vapi:lookup($name as xs:string, $arity as xs:integer) {
    try {
        function-lookup(xs:QName($name), $arity)
    } catch * {
        ()
    }
};

(:~
 : Example of a custom API function.
 : This one generates a table of contents based on milestones or divs.
 :
 : @param $request a map representing the API request
 : @return a JSON string representing the table of contents
 :)

declare function dmod-vapi:table-of-contents($request as map(*)) as node() {
    
};

(:~
: Retrieve information about the available endpoints in the dts-mod module
: @param $request a map representing the API request
: @param $ref an optional reference to be included in the rendered HTML
: @return a rendered HTML representing the endpoint information combined with the 'ref' parameter value, if provided
:)
declare function dmod-vapi:endpoint-infos($request as map(*)) as node()* {
    let $resource := normalize-space($request?parameters?resource)
    let $ref := normalize-space($request?parameters?ref)
    let $templatePath := "/templates/components/dts-metadata-panel.html"
    (: public-dts-server ends with a slash :)
    let $documentLink :=
        if ($resource ne "") then
            $custom-config:public-dts-server || "document/?resource=" || encode-for-uri($resource)
        else ""
    let $excerptLink :=
        if ($documentLink ne "" and $ref ne "") then
            $documentLink || "&amp;ref=" || encode-for-uri($ref)
        else ""
    let $model := map:merge((
        vapi:load-config-json($request),
        map {
            "server-link": $custom-config:public-dts-server,
            "document-link": $documentLink,
            "excerpt-link": $excerptLink
        }
    ))
    return
        if (doc-available($config:app-root || $templatePath)) then
            tmpl:process(serialize(config:resolve($templatePath)), $model, map {
                "plainText": false(),
                "resolver": vapi:resolver#1,
                "modules": map {
                    "http://www.tei-c.org/tei-simple/config": map {
                        "prefix": "config",
                        "at": "modules/config.xqm"
                    },
                    "http://www.tei-c.org/tei-simple/custom-config": map {
                        "prefix": "custom-config",
                        "at": "modules/custom-config.xqm"
                    }
                }
            })
        else
            <div>Template not available</div>
};

declare function dmod-vapi:view($request as map(*)) {
    (: view a single DTS resource :)

    let $docid := if (map:contains($request?parameters, "docid")) then $request?parameters?docid else ()
    let $xmlid := if (map:contains($request?parameters, "xmlId")) then $request?parameters?xmlId else ()
    let $data := dts-client:get-resource($docid, $xmlid)
    let $config := dmod-vapi:get-config($data, $request?parameters?view)
    let $templateName := head((dmod-vapi:get-template($config, $request?parameters?template), $config:default-template))
    let $templatePaths := ($config:app-root || "/templates/pages/" || $templateName, $config:app-root || "/templates/" || $templateName)

    let $template :=
        for-each($templatePaths, function($path) {
            if (doc-available($path)) then
                doc($path)
            else
                ()
        }) => head()


    return
        if (not($template)) then
            error($errors:NOT_FOUND, "template " || $templateName || " not found")
        else
            let $templateContent := serialize($template)
            let $frontmatter := tmpl:frontmatter($templateContent)
            let $config := tpu:parse-pi(root($data), $request?parameters?view, $request?parameters?odd)
            let $jsonConfig := vapi:load-config-json($request)
            let $mergedConfig := dmod-vapi:merge-config($jsonConfig, $config)
            let $_ := console:log($docid)
            let $_ := console:log($xmlid)
            let $model := map:merge((
                $mergedConfig,
                map {
                    "doc": map {
                        "content": $data,
                        "path": $docid,
                        "odd": replace($config?odd, '^(.*)\.odd', '$1'),
                        "view": $config?view,
                        "transform": page:transform(?, ?, $config?odd),
                        "transform-with": page:transform#3
                    },
                    "template": $templateName,
                    "media": if (map:contains($config, 'media')) then $config?media else ()
                }
            ))
            return
            (
                tmpl:process($templateContent, $model, map {
                    "plainText": false(),
                    "resolver": vapi:resolver#1,
                    "modules": map {
                        "http://www.tei-c.org/tei-simple/config": map {
                            "prefix": "config",
                            "at": "modules/config.xqm"
                        },
                        "http://www.tei-c.org/tei-simple/custom-config": map {
                            "prefix": "custom-config",
                            "at": "modules/custom-config.xqm"
                        }
                    },
                    "namespaces": map {
                        "tei": "http://www.tei-c.org/ns/1.0"
                    }
                })
            )
};

(:~
: Merge the JSON config with the document/collection config
: the following functions are copies, with some modifications, of the vapi:f private functions from the view module
:)
declare %private function dmod-vapi:merge-config($jsonConfig as map(*), $docConfig as map(*)) {
    let $cleanedConfig := map:merge((
        (: Only keep keys that are not relevant for ODD processing :)
        for $key in map:keys($docConfig)[not(. = ('odd', 'fill', 'depth', 'media', 'view', 'template', 'output', 'type'))]
        return
            map:entry($key, $docConfig($key))
    ))
    return
        tmpl:merge-deep(($jsonConfig, $cleanedConfig))
};

declare %private function dmod-vapi:get-config($doc as document-node(), $view as xs:string?) {
    tpu:parse-pi(root($doc), $view)
};

declare %private function dmod-vapi:get-template($config as map(*), $template as xs:string?) {
    if ($template) then
        $template
    else
        $config?template
};