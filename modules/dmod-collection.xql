xquery version "3.1";


module namespace dmod-capi="http://teipublisher.com/api/dmod-capi";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace custom-config = "http://www.tei-c.org/tei-simple/custom-config" at "./custom-config.xqm";
import module namespace dts-client = "http://www.tei-c.org/tei-publisher/dts-client" at "./dts-mod/dts-client.xql";
import module namespace console = "http://exist-db.org/xquery/console";
import module namespace vapi="http://teipublisher.com/api/view" at "view.xql";
import module namespace tmpl="http://e-editiones.org/xquery/templates";

declare function dmod-capi:list($request as map(*)) {
    (: todo create a fallback in case the DTS is not available. the fallback will redirect to the capi:list function :)
    
    let $collection := if (map:contains($request?parameters, "collection")) then $request?parameters?collection else ()
    
    (: check if the DTS endpoint is available :)
    
    let $status := serialize(dts-client:ping(), map { "method": "json" })
    return (
        serialize(dts-client:ping(), map { "method": "json" }),
        dmod-capi:list-dts($request)
    )
};

declare function dmod-capi:list-dts($request as map(*)) as element(div) {
    
    let $path := $request?parameters?path
    let $per-page := $request?parameters?per-page
    let $start :=
        xs:integer(
            head((
                $request?parameters?start,
                1
            ))
        )

    let $page :=
        (($start - 1) idiv $per-page) + 1

    let $collection-id :=
        if (exists($path) and normalize-space($path) ne "")
        then $path
        else ()

    let $collection :=
        dts-client:get-collection(
            $collection-id,
            $page,
            $per-page
        )
    (: let $works :=
        dts-client:dts-resources($collection) :)
    let $works := map:get($collection, "member")
    let $total :=
        if (exists($collection?totalChildren))
        then xs:integer($collection?totalChildren)
        else count($works)

    let $full_path := $config:app-root || $custom-config:template_path
    let $template := config:resolve($custom-config:template_path) => serialize()
    let $context := map {
        "title": "My app",
        "data": $works
    }
    return (
        response:set-header(
            "pb-start",
            xs:string($start)
        ),
        response:set-header(
            "pb-total",
            xs:string($total)
        ),
        if (doc-available($full_path))
        then tmpl:process($template, $context, map { 
            "plainText": false(),
            "resolver": vapi:resolver#1,
                "modules": map {
                    "http://www.tei-c.org/tei-simple/custom-config": map {
                        "prefix": "custom-config",
                        "at": "modules/custom-config.xqm"
                    },
                    "http://www.tei-c.org/tei-simple/config": map {
                        "prefix": "config",
                        "at": "modules/config.xqm"
                    }
                }
            })
        else <div>Template not available</div>
        
        )
};