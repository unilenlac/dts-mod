xquery version "3.1";

module namespace dmod-util="http://www.ftsr.unil.ch/dts-mod/utils";

import module namespace console="http://exist-db.org/xquery/console";
import module namespace custom-config="http://www.tei-c.org/tei-simple/custom-config"
    at "../custom-config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function dmod-util:resource-id($node as node()) as xs:string? {
    let $document := root($node)
    return
        if ($custom-config:resource-id-source = "document-name") then
            let $filename := tokenize(string(document-uri($document)), "/")[last()]
            return replace($filename, '\.[^.]+$', '')
        else if ($custom-config:resource-id-source = "xml-id") then
            let $element := head(
                $document/*/descendant-or-self::*[
                    namespace-uri(.) = $custom-config:resource-id-element-namespace
                    and local-name(.) = $custom-config:resource-id-element-name
                ]
            )
            return
                string($element/@xml:id)
        else
            ()
};

declare %private function dmod-util:citation-types($structures as item()*) as xs:string* {
    for $structure in $structures
    let $cite-type := string($structure?citeType)
    return (
        if ($cite-type = "milestone") then "milestone"
        else if ($cite-type = "page") then "pb"
        else if ($cite-type = "line") then "lb"
        else (),
        dmod-util:citation-types($structure?citeStructure?*)
    )
};

declare function dmod-util:reference-fragment(
    $source-element as element(),
    $match as element(),
    $navigation as map(*)?
) as node()* {
    let $matched-text := head(
        $source-element/descendant-or-self::text()[contains(., normalize-space(string($match)))]
    )
    let $citation-types := dmod-util:citation-types(
        $navigation?resource?citationTrees?*?citeStructure?*
    )
    let $context-names :=
        if (exists($citation-types)) then distinct-values($citation-types)
        else ("milestone", "pb", "lb")
    let $context-marker :=
        $matched-text/preceding-sibling::*[local-name(.) = $context-names][1]
    let $next-element := $matched-text/following-sibling::*[1]
    return
        if ($context-marker) then (
            dmod-util:copy-unqualified-element($context-marker),
            for $node in $context-marker/following-sibling::node()
            where empty($next-element) or $node << $next-element
            return dmod-util:copy-fragment-node($node)
        )
        else
            dmod-util:copy-unqualified-element($source-element)
};

declare %private function dmod-util:copy-fragment-node($node as node()) as node()* {
    typeswitch ($node)
        case element() return dmod-util:copy-unqualified-element($node)
        case text() return text { string($node) }
        default return ()
};

declare %private function dmod-util:copy-unqualified-element($element as element()) as element() {
    element { QName("", local-name($element)) } {
        $element/@*[namespace-uri(.) ne "http://exist.sourceforge.net/NS/exist"],
        for $child in $element/node()
        return
            typeswitch ($child)
                case element() return dmod-util:copy-unqualified-element($child)
                case text() return text { string($child) }
                default return ()
    }
};

declare function dmod-util:toc-entry($context as map(*), $content as node()?, $collapse as xs:boolean?) {
    if ($context?subNav) then
        <details>
            {
                if (not($collapse)) then
                    attribute open { "open" }
                else
                    ()
            }
            <summary>
            {
                <pb-link xml-id="{$context?docId}" emit="{$context?target}" subscribe="{$context?target}">{$context?label}</pb-link>
            }
            </summary>
            { $content }
        </details>
    else <pb-link xml-id="{$context?docId}" emit="{$context?target}" subscribe="{$context?target}">{$context?label}</pb-link>
};