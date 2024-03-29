# USITC Gravity Database Adapted From the International Trade and Production Database for Estimation (ITPD-E) and Dynamic Gravity Dataset (DGD)

<!-- badges: start -->
<!-- badges: end -->

**This repository is unmaintained, please see the new repository https://github.com/pachadotdev/gravitydatasets.**


## About

The goal of `usitcgravity` is to provide data from [The International Trade and Production Database for Estimation (ITPD-E)](https://www.usitc.gov/data/gravity/itpde.htm) and the [Dynamic Gravity Dataset (DGD)](https://www.usitc.gov/data/gravity/dgd.htm) ready to be used in R (i.e. with the [gravity](https://pacha.dev/gravity) package).

The package provides consistent data on international and domestic trade for 243 countries, 170 industries, and 17 years alongside variables for gravity estimation. The data sources are ITPD-E and DGD from the USITC, which use administrative data and intentionally does not include information estimated by statistical techniques, which makes the datasets suitable for gravity estimation.

`usitcgravity` can be installed by running

```
# install.packages("remotes")
install_github("pachadotdev/usitcgravity")
```

## Sources

Borchert, Ingo & Larch, Mario & Shikher, Serge & Yotov, Yoto, 2020. *The International Trade and Production Database for Estimation (ITPD-E)*. School of Economics Working Paper Series 2020-5, LeBow College of Business, Drexel University.

Gurevich, Tamara & Herman, Peter, 2018. *The Dynamic Gravity Dataset: 1948-2016*. USITC Working Paper 2018-02-A.

## Differences with the original sources.

Since v0.1:

* Fixes duplicated ISO3 code + Dynamic code for Cambodia and West Samoa
* Fixes duplicated label "south_east_asia" vs "suth_east_asia"

Since v0.2:

* Fixes inconsistencies in the gravity table

The last point deserves an example. See the differences in the `common_colonizer` variable for Argentina-Chile-Peru and Spain. This variable should be the same, for example, for ARG-CHL or CHL-ARG, but it's not in the original dataset.

```
> tbl(con, "usitc_gravity") %>% 
+   filter(iso3_o == "ARG", iso3_d %in% c("CHL", "ESP", "PER"), year == 2015) %>%
+   select(iso3_o, iso3_d, colony_of_origin_ever, colony_of_destination_ever, colony_ever, common_colonizer)
# Source:   SQL [3 x 6]
# Database: postgres  [pacha@localhost:5432/tariff_man]
  iso3_o iso3_d colony_of_origin_ever colony_of_destination_ever colony_ever common_colonizer
  <chr>  <chr>                  <int>                      <int>       <int>            <int>
1 ARG    CHL                        0                          0           0                0
2 ARG    ESP                        0                          1           1                0
3 ARG    PER                        0                          0           0                0

> tbl(con, "usitc_gravity") %>% 
+   filter(iso3_d == "ARG", iso3_o %in% c("CHL", "ESP", "PER"), year == 2015) %>%
+   select(iso3_o, iso3_d, colony_of_origin_ever, colony_of_destination_ever, colony_ever, common_colonizer)
# Source:   SQL [3 x 6]
# Database: postgres  [pacha@localhost:5432/tariff_man]
  iso3_o iso3_d colony_of_origin_ever colony_of_destination_ever colony_ever common_colonizer
  <chr>  <chr>                  <int>                      <int>       <int>            <int>
1 CHL    ARG                        0                          0           0                1
2 ESP    ARG                        1                          0           1                0
3 PER    ARG                        0                          0           0                1
```

I corrected this by using the gravity table itself in two ways:

* By binding rows on a pairwise basis for all symmetrical variables (i.e., `common_colonizer`) and obtained the maximum for each pair.
* By obtaining a full join on a pairwise basis for all non-symmetrical variables (i.e., `colony_of_origin_ever`) and obtained the maximum for each pair.

To check this I ran some queries to verify, for example, that the populations for CHL-ESP are around `c(20,40)` and not `c(40,40)` (i.e., Spain doubles the population of Chile), and that for the same pair `colony_of_origin_ever = 0` but for ESP-CHL `colony_of_origin_ever = 1`.

## Usage

Estimating the gravity model of trade with exporter/importer time fixed effects for 4 sectors:

```r
library(usitcgravity)
library(dplyr)
library(purrr)
library(fixest)

con <- usitcgravity_connect()
  
# run one model per sector
models <- map(
  tbl(con, "sector_names") %>% pull(broad_sector_id),
  function(s) {
    message(s)
    
    yrs <- seq(2005, 2015, by = 5)
    
    d <- tbl(con, "trade") %>% 
      filter(year %in% yrs, broad_sector_id == s) %>% 
      group_by(year, exporter_iso3, importer_iso3, broad_sector_id) %>% 
      summarise(trade = sum(trade, na.rm = T)) %>% 
      inner_join(
        tbl(con, "gravity") %>% 
          filter(year %in% yrs) %>% 
          select(iso3_o, iso3_d, contiguity, common_language, colony_ever, distance),
        by = c("exporter_iso3" = "iso3_o", "importer_iso3" = "iso3_d")
      ) %>% 
      collect()
    
    d <- d %>% 
      mutate(
        etfe = paste(exporter_iso3, year, sep = "_"),
        itfe = paste(importer_iso3, year, sep = "_")
      )
    
    feglm(trade ~ contiguity + common_language + colony_ever + 
            log(distance) | etfe + itfe,
          family = quasipoisson(),
          data = d)
  }
)

usitc_disconnect()
```

```r
print(models)

[[1]]
GLM estimation, family = quasipoisson, Dep. Var.: trade
Observations: 246,359 
Fixed-effects: etfe: 666,  itfe: 685
Standard-errors: Clustered (etfe) 
                 Estimate Std. Error   t value   Pr(>|t|)    
contiguity      -1.107178   0.095210 -11.62882  < 2.2e-16 ***
common_language  0.904003   0.093483   9.67025  < 2.2e-16 ***
colony_ever     -0.574003   0.123660  -4.64179 4.1623e-06 ***
log(distance)   -2.296888   0.049558 -46.34779  < 2.2e-16 ***
---
Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
                                           
  Squared Cor.: 0.995066                   

[[2]]
GLM estimation, family = quasipoisson, Dep. Var.: trade
Observations: 399,386 
Fixed-effects: etfe: 699,  itfe: 699
Standard-errors: Clustered (etfe) 
                 Estimate Std. Error   t value   Pr(>|t|)    
contiguity      -0.607615   0.066616  -9.12114  < 2.2e-16 ***
common_language  1.018309   0.122366   8.32184 4.5501e-16 ***
colony_ever     -0.349478   0.095461  -3.66094 2.7027e-04 ***
log(distance)   -1.231589   0.079559 -15.48011  < 2.2e-16 ***
---
Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
                                           
  Squared Cor.: 0.993537                   

[[3]]
GLM estimation, family = quasipoisson, Dep. Var.: trade
Observations: 184,626 
Fixed-effects: etfe: 658,  itfe: 682
Standard-errors: Clustered (etfe) 
                 Estimate Std. Error   t value  Pr(>|t|)    
contiguity      -1.288373   0.104177 -12.36711 < 2.2e-16 ***
common_language  1.346375   0.132477  10.16305 < 2.2e-16 ***
colony_ever     -0.288694   0.222472  -1.29766   0.19486    
log(distance)   -2.298326   0.074100 -31.01657 < 2.2e-16 ***
---
Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
                                           
  Squared Cor.: 0.992104                   

[[4]]
GLM estimation, family = quasipoisson, Dep. Var.: trade
Observations: 46,471 
Fixed-effects: etfe: 578,  itfe: 579
Standard-errors: Clustered (etfe) 
                 Estimate Std. Error    t value  Pr(>|t|)    
contiguity      -2.671951   0.183676 -14.547108 < 2.2e-16 ***
common_language  1.612853   0.127480  12.651800 < 2.2e-16 ***
colony_ever      0.139065   0.170706   0.814645   0.41561    
log(distance)   -2.267023   0.081150 -27.936349 < 2.2e-16 ***
---
Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
                                           
  Squared Cor.: 0.998325
```
