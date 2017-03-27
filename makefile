# @Author: Josh Weinflash
# @Created: 2017-03-10
# @Purpose: Makefile for Makeover Monday Week 6 (Chiacgo taxi)

src = scripts
dat = data
plt = plots
crp = crop
doc = docs

all_src = $(src)/pickups.R $(src)/dropoffs.R $(src)/evening-dropoffs.R \
          $(src)/helper.R

all_dat = $(dat)/taxi.db $(dat)/community-area.dbf $(dat)/community-area.prj \
          $(dat)/community-area.shp $(dat)/community-area.shx
					 
all_plt = $(plt)/pickups.png $(plt)/dropoffs.png $(plt)/evening-dropoffs.png

all_crp = $(crp)/pickups-small.png $(crp)/dropoffs-small.png  \
          $(crp)/evening-dropoffs-small.png

all: README.md
	
README.md: $(doc)/analysis.Rmd $(doc)/analysis-helper.R \
	         $(all_src) $(all_dat) $(all_plt) $(all_crp)
	cd $(<D); Rscript -e 'knitr::knit("analysis.Rmd", "../README.md")'

$(plt)/%.png: $(src)/%.R $(src)/helper.R $(all_dat)
	cd $(<D); Rscript $(<F)
	
clean:
	rm -f $(plt)/*
