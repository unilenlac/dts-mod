xquery version "3.1";


module namespace dmod-dapi="http://teipublisher.com/api/dmod-dapi";

import module namespace util="http://exist-db.org/xquery/util";
import module namespace console="http://exist-db.org/xquery/console";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace custom-config="http://www.tei-c.org/tei-simple/custom-config" at "./custom-config.xqm";
import module namespace dts-client="http://www.tei-c.org/tei-publisher/dts-client" at "./dts-mod/dts-client.xql";
import module namespace tmpl="http://e-editiones.org/xquery/templates";
import module namespace cutil="http://teipublisher.com/api/cache" at "caching.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "../util.xql";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "../pages.xql";

declare function dmod-dapi:get-fragment($request as map(*)) {
    let $path := $request?parameters?doc
    let $docs := dts-client:get-resource($request?parameters?doc, ())
    return dmod-dapi:get-fragment($request, $docs, $path)
    (: todo : handle caching with a DTS oriented cache utility
        if($docs)
        then (
            cutil:check-last-modified($request, $docs, dmod-dapi:get-fragment(?, ?, $path))
        ) else (
            router:response(404, "text/text", $path)
        )
    :)
};

declare function dmod-dapi:get-fragment($request as map(*), $docs as document-node()*, $path as xs:string) {
    let $view := head(($request?parameters?view, $config:default-view))
    let $xml :=
        if (exists($request?parameters?id) and $request?parameters?id != "" and $request?parameters?view != 'single') then
            for $document in $docs
            let $config := tpu:parse-pi(root($document), $view)
            let $context := dmod-dapi:apply-xpath($request, $document)
            let $data := $docs
            (:
                if (count($request?parameters?id) = 1) then
                    if ($view = "div") then
                        nav:get-section-for-node($config, $context/id($request?parameters?id))
                    else
                        $document/id($request?parameters?id)
                else
                    let $ms1 := $context/id($request?parameters?id[1])
                    let $ms2 := $context/id($request?parameters?id[2])
                    return
                        if ($ms1 and $ms2) then
                            nav-tei:milestone-chunk($ms1, $ms2, $context/tei:TEI)
                        else
                            ()
            :)
            return
                map {
                    "config": map:merge(($config, map { "context": $context })),
                    "odd": $config?odd,
                    "view": $config?view,
                    "data": $data
                }
        else if ($request?parameters?xpath) then
            for $document in $docs
            let $data := dmod-dapi:apply-xpath($request, $document)
            return
                if ($data) then
                    pages:load-xml($data, $view, $request?parameters?root, $path)
                else
                    ()
        else
            pages:load-xml($docs, $view, $request?parameters?root, $path)
    return
        if ($xml?data) then
            let $userParams :=
                map:merge((
                    request:get-parameter-names()[starts-with(., 'user')] ! map { substring-after(., 'user.'): request:get-parameter(., ()) },
                    map { "webcomponents": 7 }
                ))
            let $mapped :=
                if ($request?parameters?map) then
                    let $mapFun := function-lookup(xs:QName("mapping:" || $request?parameters?map), 2)
                    let $mapped := $mapFun($xml?data, $userParams)
                    return
                        $mapped
                else
                    $xml?data
            let $data :=
                if (empty($request?parameters?xpath) and request:get-parameter('user.highlight', ()) and exists(session:get-attribute($config:session-prefix || ".search"))) then
                    query:expand($xml?config, $mapped)[1]
                else
                    $mapped
            let $content :=
                if (not($view = "single")) then
                    pages:get-content($xml?config, $data)
                else
                    $data

            let $html :=
                typeswitch ($mapped)
                    case element() | document-node() return
                        pages:process-content($content, $xml?data, $xml?config, $userParams, $request?parameters?wrap)
                    default return
                        $content
            let $transformed := dapi:extract-footnotes($html[1], $xml?data[1])
            let $path := replace($path, "^.*/([^/]+)$", "$1")
            return
                if ($request?parameters?format = "html") then
                    router:response(200, "text/html", $transformed?content)
                else
                    let $next := if ($view = "single") then () else $config:next-page($xml?config, $xml?data, $view)
                    let $prev := if ($view = "single") then () else $config:previous-page($xml?config, $xml?data, $view)
                    return
                        router:response(200, "application/json",
                            map {
                                "format": $request?parameters?format,
                                "view": $view,
                                "doc": $path,
                                "root": $request?parameters?root,
                                "rootNode": util:node-id($xml?data[1]),
                                "id": $content/@xml:id/string(),
                                "odd": $xml?config?odd,
                                "next":
                                    if ($next) then
                                        util:node-id($next)
                                    else (),
                                "previous":
                                    if ($prev) then
                                        util:node-id($prev)
                                    else
                                        (),
                                "nextId":
                                    if ($next) then
                                        $next/@xml:id/string()
                                    else (),
                                "previousId":
                                    if ($prev) then
                                        $prev/@xml:id/string()
                                    else
                                        (),
                                "switchView":
                                    if ($view != "single") then
                                        let $node := pages:switch-view-id($xml?data, $view)
                                        return
                                            if ($node) then
                                                util:node-id($node)
                                            else
                                                ()
                                    else
                                        (),
                                "content": serialize($transformed?content,
                                    <output:serialization-parameters xmlns:output="http://www.w3.org/2010/xslt-xquery-serialization">
                                            <output:indent>no</output:indent>
                                            <output:method>{$request?parameters?serialize}</output:method>
                                            <output:omit-xml-declaration>yes</output:omit-xml-declaration>
                                        </output:serialization-parameters>),
                                "footnotes": serialize($transformed?footnotes,
                                    <output:serialization-parameters xmlns:output="http://www.w3.org/2010/xslt-xquery-serialization">
                                        <output:indent>no</output:indent>
                                        <output:method>{$request?parameters?serialize}</output:method>
                                        <output:omit-xml-declaration>yes</output:omit-xml-declaration>
                                    </output:serialization-parameters>
                                ),
                                "userParams": $userParams,
                                "collection": dapi:get-collection($xml?data[1])
                            }
                        )
        else
            error($errors:NOT_FOUND, "Document " || $path || " not found")
};

(::)

declare %private function dmod-dapi:apply-xpath($request as map(*), $data as node()) {
    if ($request?parameters?xpath) then
        let $namespace := namespace-uri-from-QName(node-name(root($data)/*))
        let $xquery := "declare default element namespace '" || $namespace || "'; $data" || $request?parameters?xpath
        return
            util:eval($xquery)
    else
        $data
};