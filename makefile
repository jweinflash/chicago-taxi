# @Author: Josh Weinflash
# @Created: 2017-03-10
# @Purpose: Makefile for Makeover Monday Week 6 (Chiacgo taxi)

src = scripts
dat = data
doc = docs
plt = plots

all_dat = $(dat)/taxi.db $(dat)/community-area.dbf $(dat)/community-area.prj \
          $(dat)/community-area.shp $(dat)/community-area.shx
					 
all_plt = $(plt)/pickups.png $(plt)/dropoffs.png $(plt)/evening-dropoffs.png

all: $(all_plt)
	
$(plt)/%.png: $(src)/%.R $(src)/helper.R $(all_dat)
	cd $(<D); Rscript $(<F)
	
clean:
	rm -f $(plt)/* $(doc)/*
