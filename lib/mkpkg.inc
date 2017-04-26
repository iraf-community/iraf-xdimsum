# Global MKPKG definitions for the XDIMSUM package.

$set XFLAGS	= "$(XFLAGS) -p xdimsum"
$set XVFLAGS	= "$(XVFLAGS) -p xdimsum"
$set LFLAGS	= "$(LFLAGS) -p xdimsum"

#$ifeq (MACH, sparc) then
#    $include "xdimsum$lib/mkpkg.sf.SUN4"
#$else $ifeq (MACH, i386) then
#    $include "xdimsum$lib/mkpkg.sf.I386"
#$else $ifeq (MACH, f68881) then
#    $include "xdimsum$lib/mkpkg.sf.SUN3"
#$else $ifeq (MACH, ffpa) then
#    $include "xdimsum$lib/mkpkg.sf.SUN3"
#$else $ifeq (MACH, vms) then
#    $include "xdimsum$lib/mkpkg.sf.VMS"
#$else $ifeq (MACH, ddec) then
#    $include "xdimsum$lib/mkpkg.sf.DDEC"
#$else $ifeq (MACH, dmip) then
#    $include "xdimsum$lib/mkpkg.sf.DMIP"
#$else $ifeq (MACH, rs6000) then
#    $include "xdimsum$lib/mkpkg.sf.AIX3"
#$else $ifeq (MACH, mips) then
#    $include "xdimsum$lib/mkpkg.sf.MIPS"
#$end
