#!/usr/bin/env bash

SENSORS_DATA=$(sensors-m1 -t)
SENSOR_BASE="PMGR SOC Die Temp Sensor"

IFS=""

AVG=0
SENSORS=0

for i in {0..3}; do
  VALUE=$(echo ${SENSORS_DATA}|grep "${SENSOR_BASE}${i}"|cut -d'=' -f2|cut -d' ' -f2)

  [[ -z ${VALUE} ]] && break

  AVG=$(echo "${AVG}+${VALUE}"|bc -l)
  SENSORS=${i}
  VALUE=""
done

if [ -n ${AVG} -a -n ${SENSORS} -a ${SENSORS} -gt 0 ]; then
  printf "%.1fºC\n" $(echo "${AVG}/(${SENSORS}+1)"|bc -l)
else
  echo '--.-ºC'
fi
