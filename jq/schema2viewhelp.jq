# jq conversion library:  ejsonschema to doc JSON
#
# This library collects pertinent information for building
# human-readable documentation.
#

def stripref:
    gsub(".*#/definitions/"; "")
;

def iteminfo:
    if .["$ref"] then
        (.["$ref"] | stripref)
    else
        .type
    end
;

def show_type:
    if .anyOf then
      .anyOf | map(select(.type!="null") | show_type) | join(" or ")
    else
      if .["$ref"] then
        (.["$ref"] | stripref) + " object"
      else 
        if .type == "string" then
            "text" +
            if .format == "uri" then
                " (URL)"
            else
                if .format then " ("+.format+")" else "" end
            end
        else
            if .type == "array" then
                "list of " +
                if .items.type == "string" then
                    "text values"
                else (.items | show_type) + "s" end
            else
                if .type == "int" then "integer"
                else
                   if .type == "float" then "decimal"
                   else .type end
                end
            end
        end
      end
    end
;

def typeinfo:
    if .anyOf then
      (.anyOf | map(select(.type!="null")) |
       if (length > 1) then
          { type: map( typeinfo ) }
       else
          if (length > 0) then
             (.[0] | typeinfo)
          else
             { type: "null" }
          end
       end)
    else 
      if .type == "array" then
         { type, each: .items | iteminfo } 
      else
         if .["$ref"] then
            { type: "object", of: .["$ref"] | stripref }
         else
            { type }
         end
      end
    end +
    if .format then { format } else {} end +
    { show: show_type }
;

def property2valuedoc:
    if .valueDocumentation then
      ((if .enum then "allowed" else "recognized" end) as $tag |
       [{ key: $tag, value: (.valueDocumentation | map_values(.description)) }] |
       from_entries)
    else
      {}
    end
;

def property2view:
    {
      type: typeinfo,
      description: [ .description ],
      brief: .description,
      label: .title
    } +
    property2valuedoc 
;
def property2view(name; parenttype):
    { name: name, parent: parenttype } +
    property2view 
;

def ensure_title(deftitle):
    if .value.title then . else (.value.title = deftitle) end
;

def ensure_titles:
    to_entries | map( ensure_title(.key) ) | from_entries
;

def type2view(name):
    { name: name, description: [.description], brief: .description, use: [] } +
    (if .allOf then
        (.allOf |{ inheritsFrom: map(select(.["$ref"]) | .["$ref"] | stripref)})
     else {} end) + { properties:
    ((if .allOf then
        (.allOf | map(select(.properties) | .properties) 
                | reduce .[] as $itm ({}; . + $itm))
      else
        (if .properties then .properties else {} end)
      end) | ensure_titles | to_entries |
      map( .key as $key | .value | property2view($key; name) )) }
;
   
def schema2view: {
    title,
    description: [.description],
    types: (.definitions | to_entries |
            map( .key as $key | .value | type2view($key) ))
};

# this function was intended to join the outputs of multiple files.
# It doesn't work. 
def all_schema2view:
    [schema2view] |
    if (length > 1) then
        reduce .[1:length] as $s (.[0]; .types += $s.types)
    else .[0] end
;
