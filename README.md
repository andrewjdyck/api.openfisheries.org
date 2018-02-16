
# Openfisheries.org API

The Advanced Programming Interface (API) is experimental, but I welcome you to take a look and let me know what could work better. Use the details on the contact page to get in touch. 

## How it works
The API supports GET requests for annual fishery landings data at the following url: 
  
  http://openfisheries.org/api/landings.json 

and produces a valid JSON document for global fisheries landings. There are parsers for nearly every programming language for reading JSON documents including for the R-project and Python. 

### API parameters
In addition to global aggregate landings, one can download landings by country or species with the following two urls. 

http://openfisheries.org/api/landings/countries.json 

http://openfisheries.org/api/landings/species.json 

These URLs will return a complete list of all countries and species, respectively, that can be used in API calls. For example, to get an aggregate list of landings by the United States, one would use the url: 
  
  http://openfisheries.org/api/landings/countries/USA.json 

Where the final parameter ('USA') is the ISO-3166 alpha 3 country code. Similarly, one can download all landings for skipjack tuna using the following url: 
  
  http://openfisheries.org/api/landings/species/SKJ.json 

Where the last parameter in the url ('SKJ') is the three-letter ASFIS species code 
Additional API work will allow downloads by FAO statistical area, marine/inland species designation and the ability to download by multiple parameters, ie. download all skipjack tuna landings by Japan in the year 2000. Until then, feel free to contact me for more info about the API.

## API data sources

### FAO Global fisheries capture landings
Data for the OpenFisheries landings API is sourced from the UN Food and Agriculture Organization. [FishstatJ](http://www.fao.org/fishery/statistics/software/fishstatj/en) Capture dataset is exported to csv in /data/ with the following notes:

- Country column exported as ISO 3-letter code
- Species exported as ASFIS code
- Symbols exported as a separate column (the "S" column in the CSV)

Notes on the symbols in the FAO data are as follows:

- "0": Greater than 0, but less than 1 tonne
- "-": Equal to zero
- "F": FAO estimate


## Contact
twitter: [@openfisheries](http://twitter.com/openfisheries)
email: openfisheries [at] gmail [dot] com
