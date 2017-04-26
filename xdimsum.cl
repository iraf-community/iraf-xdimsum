# { XDIMSUM -- Package definition script for the XDIMSUM IR array imaging
# reduction package.

# Load necessary packages.

# Currently artdata is only required for the demos task. It is not required
# for the main xdimsum package.

artdata

# Crutil is required by the new experiment cosmic ray zapping task xnzap.

imred
crutil

# Define the package. This is not required if xdimsum is not an external
# pacakge.

cl < "xdimsum$lib/zzsetenv.def"
package xdimsum, bin = xdimsumbin$

# Main XDIMSUM tasks

task badpixupdate 	= "xdimsum$src/badpixupdate.cl"
task iterstat		= "xdimsum$src/iterstat.cl"
task miterstat		= "xdimsum$src/miterstat.cl"
task maskdereg		= "xdimsum$src/maskdereg.cl"
task maskfix		= "xdimsum$src/maskfix.cl"
task maskstat		= "xdimsum$src/maskstat.cl"
task mkmask		= "xdimsum$src/mkmask.cl"
task orient		= "xdimsum$src/orient.cl"
task sigmanorm		= "xdimsum$src/sigmanorm.cl"
task xdshifts		= "xdimsum$src/xdshifts.cl"
task xfirstpass		= "xdimsum$src/xfirstpass.cl"
task xfshifts		= "xdimsum$src/xfshifts.cl"
task xlist		= "xdimsum$src/xlist.cl"
task xmaskpass		= "xdimsum$src/xmaskpass.cl"
task xmskcombine	= "xdimsum$src/xmskcombine.cl"
task xmosaic		= "xdimsum$src/xmosaic.cl"
task xmshifts		= "xdimsum$src/xmshifts.cl"
task xnregistar		= "xdimsum$src/xnregistar.cl"
task xnslm		= "xdimsum$src/xnslm.cl"
task xnzap		= "xdimsum$src/xnzap.cl"
task xrshifts		= "xdimsum$src/xrshifts.cl"
task xslm		= "xdimsum$src/xslm.cl"
task xzap		= "xdimsum$src/xzap.cl"

# Additional hidden XDIMSUM tasks required by the main XDIMSUM tasks.

task addcomment		= "xdimsum$src/addcomment.cl"
task avshift		= "xdimsum$src/x_xdimsum.e"
task fileroot		= "xdimsum$src/fileroot.cl"
task makemask		= "xdimsum$src/makemask.cl"
task maskinterp 	= "xdimsum$src/x_xdimsum.e"
task minv		= "xdimsum$src/minv.cl"
task xaddmask		= "xdimsum$src/xaddmask.cl"

hidetask addcomment avshift fileroot maskinterp minv xaddmask


# Demos

set	demos	= "xdimsum$demos/"
task	demos	= "demos$demos.cl"

# Cache task parameters to avoid background execution problems. May need
# to go through and eventually replace some of these calls, e.g. replace
# imgets with hselect, etc.

cache sections fileroot imgets minmax iterstat miterstat maskstat xaddmask

clbye()
