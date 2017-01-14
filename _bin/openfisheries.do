* openfisheries.do

* load data
*global data = "/var/www/openfisheries.org/data/"
*global data = "C:\Users\a.dyck\Documents\My Dropbox\business\openfisheries\"
global data = "/home/andrew/Dropbox/business/openfisheries.org/data/"
insheet using "${data}capture1950to2009.csv", comma clear

* re-label and reshape
rename v1 country
rename v2 species
rename v3 area
rename v4 measure
drop if measure == "Quantity (number)"

forvalues i = 5/64 {
	local y = `i' + 1945
	rename v`i' catch`y'
}

drop in 1
drop if regexm(country, "Totals")

* add and fix iso3c codes
kountry country, from(other) stuck
rename _ISO iso3n
kountry iso3n, from(iso3n) to(iso3c)

* reshape
reshape long catch, i(country species area) j(year)

* clean non-numerics
replace catch = "" if catch == "..." | catch == "-"
replace catch = subinstr(catch, " ", "", .)
replace catch = subinstr(catch, "F", "", .)
destring catch, replace
drop measure
replace species = subinstr(species, "[", "", .)
replace species = subinstr(species, "]", "", .)
replace species = lower(species)


* fix area variables
replace area = lower(area)
split area, parse(" - ") gen(location)
rename location2 inland
drop area
split location1, parse(",") gen(subarea)
drop location1
rename subarea2 subarea
rename subarea1 area
replace inland = 0 if inland == ""
replace inland = 1 if inland == "inland waters"
destring inland, replace



local conn = "DRIVER={MySQL ODBC 5.1 Driver};SERVER=mysql.midcoastdata.com;DATABASE=openfisheries;UID=anddyc1;PWD=miDc0astd8A"

odbc insert, table("fao_capture") create conn("`conn'") sqlshow


* output by country
collapse (sum) catch, by(country year)


outsheet using "${data}capture.csv"





* end
