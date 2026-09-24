xquery version "3.1";

(:~
 : A set of helper functions to access the application context from
 : within a module.
 :)
module namespace custom-config="http://www.tei-c.org/tei-simple/custom-config";

(: DTS configuration :)

declare variable $custom-config:template_path := "/templates/components/dts-collection-list.html";

declare variable $custom-config:dts-server := "[[ $context?dts-mod?dts-endpoint ]]";

declare variable $custom-config:dts-root-collection := "collection";