#!/bin/bash

KIBANA_DIR=../arcsight/kibana/6.x
OUTPUT_FULL_PATH=./kibana/paloalto_kibana_obj.json
declare -a UUID_ALL
## header of file
> ${OUTPUT_FULL_PATH}
cat >> ${OUTPUT_FULL_PATH} << END
{
  "objects": [
END

## add searches


for item in $(ls ${KIBANA_DIR}/search)
  do
    UUID=$(basename ${item} .json)
    UUID_ALL+=( ${UUID} )
    JS_CONTENT=$(cat ${KIBANA_DIR}/search/${item})
cat >> ${OUTPUT_FULL_PATH} << END
{
  "id": "${UUID}",
  "type": "search",
  "version": 1,
  "attributes": ${JS_CONTENT}
},
END
done



## add visualization


for item in $(ls ${KIBANA_DIR}/visualization)
  do
    UUID=$(basename ${item} .json)
    UUID_ALL+=( ${UUID} )
    JS_CONTENT=$(cat ${KIBANA_DIR}/visualization/${item})
cat >> ${OUTPUT_FULL_PATH} << END
{
  "id": "${UUID}",
  "type": "visualization",
  "version": 1,
  "attributes": $JS_CONTENT
},
END
done

## add dashboard


for item in $(ls ${KIBANA_DIR}/dashboard|grep -v arcsight)
  do
    UUID=$(basename ${item} .json)
    JS_CONTENT=$(cat ${KIBANA_DIR}/dashboard/${item})
cat >> ${OUTPUT_FULL_PATH} << END
{
  "id": "${UUID}",
  "type": "dashboard",
  "version": 1,
  "attributes": $JS_CONTENT
},
END
done

## fix the end
sed -i '$ s/},/}\n]\n}/g' ${OUTPUT_FULL_PATH}


## replace title

sed -i '/title\":/s/\([A-Z].*\)\s\[.*\]/PaloAlto: \1/g'  ${OUTPUT_FULL_PATH}
sed -i  '/title\":/s/\[.*\]\s\([A-Z].*\)/PaloAlto: \1/g'  ${OUTPUT_FULL_PATH}

## replace index pattern
sed -i 's/arcsight-\*/paloalto-\*/g'  ${OUTPUT_FULL_PATH}

## replace all Arcsight string
sed -i 's/ArcSight/PaloAlto/g'  ${OUTPUT_FULL_PATH}

## replace UUID with new one
for uuid in ${array[*]}
  do
  new_uuid=$(uuid)
  sed -i "s/$uuid/$new_uuid/g" ${OUTPUT_FULL_PATH}
done
