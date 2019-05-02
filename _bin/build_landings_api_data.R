
source('./_bin/fao_data_utils.r')
source('./_bin/prepare_api_json_data.r')

data_file <- './data/fishstat_export_s_capture2018.csv'
in_data <- read_fao_data(data_file)
clean_fao_data(in_data, years=1950:2017)

# Creates a tidy dataset
prep_fao_fishstat_data(out_data)

# CAUTION!! 
# remove any existing files in the api/landings directory
# clean_landings_files()

# Create a master json file for global landings
dir.create('./api/')
dir.create('./api/landings')
file.copy('./data/countries.json', './api/landings/countries.json')
file.copy('./data/species.json', './api/landings/species.json')
dir.create('./api/landings/countries/')
dir.create('./api/landings/species/')

output_global_json(out_data)
output_global_disagg_csv(out_data)
output_country_json(country_list)
output_species_json(species_list)
output_global_json(out_data)


writeLines(
  toJSON(
    data.frame(
      version=0.4, 
      url='http://api.openfisheries.org'
    )
  ),
 './api/api.json'
)
