
source('./_bin/fao_data_utils.r')
source('./_bin/prepare_api_json_data.r')

data_file <- './data/fishstat_export_s_capture2016.csv'
in_data <- read_fao_data(data_file)
clean_fao_data(in_data, years=1950:2014)

prep_fao_fishstat_data(out_data)

output_country_json(country_list)
output_species_json(species_list)

#writeLines(
#  toJSON(data.frame(version=0.1, url='http://api.openfisheries.org')),
#  '../api/api.json'
#)
