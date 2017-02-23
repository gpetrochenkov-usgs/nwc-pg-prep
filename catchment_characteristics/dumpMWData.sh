 username=$1
 password=$2
 check=$3

 if [ -z "$username" ]; then
      echo "You must pass in two variables, admin username, password."
      exit
 fi

 if [ -n "$check" ]; then
     echo "You must pass in two variables, admin username, password."
     exit
 fi

 pg_dump -Fc -t characteristic_data.characteristic_metadata postgresql://$username:$password@localhost/nldi -O --file="characteristic_data.characteristic_metadata.pgdump"
 pg_dump -Fc -t characteristic_data.divergence_routed_characteristics postgresql://$username:$password@localhost/nldi -O --file="characteristic_data.divergence_routed_characteristics.pgdump"
 pg_dump -Fc -t characteristic_data.total_accumulated_characteristics postgresql://$username:$password@localhost/nldi -O --file="characteristic_data.total_accumulated_characteristics.pgdump"
 pg_dump -Fc -t characteristic_data.local_catchment_characteristics postgresql://$username:$password@localhost/nldi -O --file="characteristic_data.local_catchment_characteristics.pgdump"
#
for file in *.pgdump; do gzip $file; done;

# curl -u dblodgett --insecure -X PUT "https://cidasdpdasartip.cr.usgs.gov:8444/artifactory/nldi/datasets/characteristic_data.characteristic_metadata.pgdump.gz" -T characteristic_data.characteristic_metadata.pgdump.gz -# -o log.txt
# curl -u dblodgett --insecure -X PUT "https://cidasdpdasartip.cr.usgs.gov:8444/artifactory/nldi/datasets/characteristic_data.divergence_routed_characteristics.pgdump.gz" -T characteristic_data.divergence_routed_characteristics.pgdump.gz -# -o log.txt
# curl -u dblodgett --insecure -X PUT "https://cidasdpdasartip.cr.usgs.gov:8444/artifactory/nldi/datasets/characteristic_data.total_accumulated_characteristics.pgdump.gz" -T characteristic_data.total_accumulated_characteristics.pgdump.gz -# -o log.txt
# curl -u dblodgett --insecure -X PUT "https://cidasdpdasartip.cr.usgs.gov:8444/artifactory/nldi/datasets/characteristic_data.local_catchment_characteristics.pgdump.gz" -T characteristic_data.local_catchment_characteristics.pgdump.gz -# -o log.txt
