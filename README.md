     XDIMSUM -- Experimental Deep Infrared Mosaicing Software

THIS VERSION OF XDIMSUM WILL ONLY RUN UNDER IRAF VERSION 2.12 AND LATER. IT
REQUIRES TASKS IN THE PROTO PACKAGE THAT ARE NOT AVALILABLE IN IRAF 2.11 AS
WELL AS THE IMRED.CRUTIL PACKAGE WHICH IS NOT INSTALLED UNDER IRAF 2.11. PLEASE
WAIT TO INSTALL THIS VERSION OF XDIMSUM UNTIL AFTER IRAF 2.12 IS RELEASED.

XDIMSUM is a package for creating accurate sky subtracted images from sets of
dithered observations. While the observations need not be in the infrared, the
dominance of the variable sky background in infrared data requires dithering of
many short exposures and recombination with careful sky subtraction to produce
deep images. Hence the package is called "Experimental Deep Infrared Mosaicing
Software" or XDIMSUM.

XDIMSUM is a variant of the DIMSUM package developed by P. Eisenhardt, M.
Dickensen, S.A. Stanford, and J. Ward. F. Valdes (IRAF group) modified DIMSUM
to support FITS format images, added the DIMSUM tutorial demos script, wrote
the original version of this document, and repackaged DIMSUM for distribution
as an IRAF external package.  L. Davis (IRAF group) rewrote the the major
DIMSUM scripts to improve their clarity, robustness, and efficiency, added
new scripts for computing relative offsets, and documented the tasks. The new
package uses the same default algorithms as DIMSUM but is sufficiently
different in format that it has been renamed XDIMSUM. A short summary of the
major differences between XDIMSUM and DIMSUM is provided below and is
duplicated in the on-line user's guide. XDIMSUM is being made available to the
community as an external pacakge in the hope that some of the new features may
prove useful to others. Users should direct XDIMSUM installation questions,
bug reports, questions about technical details, and comments and suggestions
to the the IRAF group (iraf@noao.edu) not the original authors.

The current contents of the XDIMSUM package are

        xmosaic - Driver sript for first pass and mask pass processing steps
     xfirstpass - Driver script for first pass processing steps
      xmaskpass - Driver script for mask pass processing steps

           xslm - Sky subtract images using running median
        maskfix - Fix bad pixel in images using a bad pixel mask
           xzap - Remove cosmic rays from images using median filtering
          xnzap - Remove cosmis rays from images using averaging filter
   badpixupdate - Update bad pixel mask to include bad pixels detected by xzap
     xnregistar - Mosaic the images using sub-pixel replication and masking
         mkmask - Create the initial master object mask
      maskdereg - Deregister master object mask to individual object masks
       xdshifts - Compute shifts using image display and centroiding techniques
       xfshifts - Compute shifts using star finding and centroiding techniques
       xmshifts - Compute shifts using star finding and list matching techniques
       xrshifts - Compute shifts using x-correlation techniques

       iterstat - Compute image statistics using iterative rejection
          xlist - Create image sublists used by xslm
       makemask - Make an object mask for a single image
         orient - Reorient image to N up and E left or undo re-orientation
      sigmanorm - Renormalize mosaic image to uniform pixel-to-pixel rms
       maskstat - Compute mask statistics using iterative rejection

          demos - Xdimsum demo data script
          guide - Guide to using xdimsum with the xmosaic task

-------------------------------------------------------------------------------
New Release: January 24, 2003

	Modification to xdshifts to avoid problem with IMEXAMINE and
	DS9.  If you use XIMTOOL then there is no need to update.

-------------------------------------------------------------------------------
New Release: August 6, 2002

	The xnregistar step was not maintaining the proper exposure
	time factors.

-------------------------------------------------------------------------------
New Release: June 27, 2002

	Fixed an undefined variable problem in the xmskcombine task.

-------------------------------------------------------------------------------
New Release: June 25, 2002

	Fixed some problems related to the default mask names in 
	xnregistar.

-------------------------------------------------------------------------------
New Release: June 19, 2002

	The cmimglist variable was undefined in the xnregistar script causing
	it to fail if interpolation instead of block replication is used.

-------------------------------------------------------------------------------
New Release: May 02, 2002

        Fixed  various problems with the ximcombine task.

-------------------------------------------------------------------------------
New Release: January 30, 2002

        Fixed an ximcombine problem in handling offsets which resulted in
        gross inefficiences when combining large images.

-------------------------------------------------------------------------------
New Release: December 4, 2001

        Fixed an ximcombine problem that only showed up on Linux.

-------------------------------------------------------------------------------
New Release: November 28, 2001

        Replaced ximcombine with the latest enhanced, bug fixed, and repackaged
        version from Frank which preserves the existing parameter set and
        behavior.

-------------------------------------------------------------------------------
New Release: August 11, 2001

        Fixed a segvio error in ximcombine that was triggered when trying to
        combine large numbers >~ 250 pixel masks.

-------------------------------------------------------------------------------
New Release: July 17, 2001
   
        Fixed an infinite loop problem in the interactive threshold determining
        algorithm in the xmosaic task.

-------------------------------------------------------------------------------
New Release: June 01, 2001

    Added the negthresh parameter to the makemask task and made the parameter
    visible to the xfirstpass, xmaskpass, and xmosaic tasks. If negthresh
    is yes both positive and negative masking threshold are used otherwise
    only positive masking threshold are used. Negthresh is set to no in
    the xzap makemask call.

    Made the badpixupdate task nrepeats parameter visible to the xfirstpass,
    xmaskpass, and xmosaic tasks.

    Made the regions growing parameter ngrow visible to the xmaskpass and
    xmosaic scripts.

    Rearranged the listing of the xmosaic task switch parameters to
    be back at the beginning of the task listing.

    Removed the nprev_omask parameter from the maskdereg task and added it
    to the xnregistar task. Also made the parameter visible to the xmaskpass
    and mosaic scripts.

    Added the omasks parameter to the xnregistar task.

    Correct various minor bugs to do with check for input file existence
    and switch values.

-------------------------------------------------------------------------------
First Release: January 08, 2001
-------------------------------------------------------------------------------

        Standard Installation Instructions For The Xdimsum Package

Installation of this external package consists ofobtaining the files, creating
a directory containing the package, compiling the executables or installing
precompiled executables, and defining the environment to load and run the
package. The package may be installed for a site or as a personal installation.
If you need help with these installation instructions contactiraf@noao.edu or
call the IRAF HOTLINE at 520-318-8160.

[arch]
    In the following steps you will need to know the IRAF architecture
    identifier for your IRAF installation. This identifier is similar
    to  the host operating system type. The identifiers are things like
    "ssun" for Solaris, "alpha" for Dec Alpha, and "linux" or "redhat"
    for most Linux systems. The IRAF architecture identifier is defined
    when you run IRAF. Start the CL and then type

        cl> show arch
        .ssun

    This is the value you need to know without the leading '.',  i.e.
    the IRAF architecture is "ssun" in the above example.

[1-site]
    If you are installing the package for a site login as IRAF and edit
    the IRAF file defining the packages.

        % cd $hlib

    Define the environment variable xdimsum to be the pathnames to the
    xdimsum package root directory and the instrument database. The '$'
    character must be escaped in the VMS pathname and UNIX pathnames must
    be terminated with a '/'.  Edit extern.pkg to include the following.

        reset xdimsum = /local/xdimsum/
        task  xdimsum.pkg = xdimsum$xdimsum.cl

    Near the end of the hlib$extern.pkg file, update the definition of
    helpdb so it includes the xdimsum help database, copying the syntax
    already used in the string. Add this line before the line containing
    a closing quote:

        ,xdimsum$lib/helpdb.mip\

[1-personal]
    If you are installing the package for personal use define a host
    environment variable with the pathname of the  directory  where  the
    package will be located (needed in order to build the package from
    the source code).  Note that  pathnames  must  end  with  '/'.   For
    example:

        % setenv xdimsum /local/xdimsum/

    In your login.cl or loginuser.cl file make the following definitions
    somewhere before the "keep" statement.

        reset xdimsum = /local/xdimsum/
        task  xdimsum.pkg = xdimsum$xdimsum.cl
        printf ("reset helpdb=%s,xdimsum$lib/helpdb.mip\nkeep\n",
            envget("helpdb")) | cl
        flpr

    If you will be compiling the package, as  opposed  to  installing  a
    binary  distribution,  then  you  need to define various environment
    variables.   The  following  is  for  Unix/csh  which  is  the  main
    supported environment.

        # Example
        % setenv iraf /iraf/iraf/             # Path to IRAF root (example)
        % source $iraf/unix/hlib/irafuser.csh # Define rest of environment
        % setenv IRAFARCH ssun                # IRAF architecture

    where   you  need  to  supply  the  appropriate  path  to  the  IRAF
    installation root in  the  first  step  and  the  IRAF  architecture
    identifier for your machine in the last step.

[2] Login  into  IRAF.   Create a directory to contain the package files
    and the  instrument  database  files.   These  directory  should  be
    outside the standard IRAF directory tree.

        cl> mkdir xdimsum$
        cl> cd xdimsum

[3] The  package is distributed as a tar archive of sources. Note that IRAF
    includes a tar reader. The tar file is most commonly obtained via anonymous
    ftp. Below is an example from a Unix machine where the compressed files
    have the ".Z" extension. Files with ".gz" or ".tgz" can be handled
    similarly.

        cl> ftp iraf.noao.edu (140.252.1.1)
        login: anonymous
        password: [your email address]
        ftp> cd iraf/extern
        ftp> get xdimsum[v212].readme
        ftp> binary
        ftp> get xdimsum[v212].tar.Z
        ftp> quit
        cl> !uncompress xdimsum[v212].tar.Z

    The readme file contains these instructions. The <arch> in the optional
    executable distribution is replaced by the IRAF architecture identification
    for your computer.

[4] Extract the source files from the tar archive using 'rtar".
   
        cl> softools
        so> rtar -xrf xdimsum[v212].tar
        so> bye

    On some systems, an error message will appear  ("Copy  'bin.generic'
    to  './bin  fails")  which  can  be ignored.  Sites should leave the
    symbolic link 'bin'  in  the  package  root  directory  pointing  to
    'bin.generic'  but can delete any of the bin.<arch> directories that
    won't be used.  If there is no binary directory for the  system  you
    are  installing  it  will  be  created  when the package is compiled
    later or when the binaries are installed.

    If the binary executables have been obtained these are now extracted
    into the appropriate bin.<arch> directory.

        # Example of sparc installation.
        cl> cd xdimsum
        cl> rtar -xrf xdimsum-bin.sparc      # Creates bin.sparc directory

The tar file can be deleted once it has been successfully installed.

[5] For a source installation you now have to build the package executable(s).
    First you configure the package for the particular architecture.

        cl> cd xdimsum
        cl> mkpkg <arch>            # Substitute sparc, ssun, alpha, etc.

    This  will  change the bin link from bin.generic to bin.<arch>.  The
    binary directory will be  created  if  not  present.   If  an  error
    occurs  in  setting  the  architecture  then  you may need to add an
    entry to the file "mkpkg".  Just follow the examples in the file.

    To create the executables and move them to the binary directory

        cl> mkpkg -p xdimsum update >& xdimsum.spool # build executables
        cl> mkpkg generic           # optionally restore generic setting

    Check for errors.  If the executables are not moved  to  the  binary
    directory  then  step [1] to define the path for the package was not
    done correctly.  The last step restores the  package  to  a  generic
    configuration.   This  is  not  necessary  if you will only have one
    architecture for the package.

This should complete the installation.  You can  now  load  the  package
and begin testing and use.

-----------------------------------------------------------------------------


Summary of Major Differences between XDIMSUM and DIMSUM


Input and Output Image and Mask Lists

All input and output image and file names and input and output image and file
lists are now task parameters rather than being silently passed as keyword
names, silently assumed to have already been created by a previous step, or
silently created by the current step. For example the input object mask list
required by the xslm task is now a parameter. Similarly the output sky
subtraction and holes mask lists produced the the xslm task are now parameters.
These changes make tracing the data flow from one processing step to another
simpler.

Default Image and Mask Names

In most cases the output images and masks are assigned sensible default names
if explicit output image and mask lists are not provided. For example in the
case of the sky subtraction task xslm the suffix ".sub" is appended to the
input images names  to produce the output sky subtracted image names, and the
suffixes ".ssm" and ".hom" are appended to sky subtracted image names to create
the sky subtraction and holes mask names.  In general if an output image or
mask list parameter value begins with a '.' it is assumed to be a suffix rather
than a complete name.  The default image and mask name scheme means that users
need not concern themselves with the names of the intermediate data products.

Use of Suffixes instead of Prefixes to Define Default Names

Suffixes instead of prefixes are used to create default names. Using suffixes
means that the input and output image lists no longer need to be in the same
directory.

New Tasks

A new sky subtraction task xnslm has been added to the XDIMSUM package.
Xnslm is a script wrapper for the rskysub task. Xnslm is an alternative
to the default xslm task. It is significantly faster than xslm.

A new cosmic ray removal task xnzap has been added to the XDIMSUM package.
Xnzap is a script wrapper for the craverage task.  Xnzap is an alternative to
the default xzap task. It is significantly faster than xzap but not yet as well
tested.  Users are encouraged to experiment with xnzap and / or xcraverage on
their own. User feedback on their effectiveness is welcome.

The code for interactively computing the relative shifts in a set of dithered
images has been rewritten and moved into a separate task called xdshifts.

Three new script tasks for computing shifts for images taken in series with
approximately constant shifts between adjacent images: xmshifts, xfshifts,
and xrshifts, have been added to XDIMSUM. These scripts use modified versions
of the existing starfind and imcentroid tasks called xstarfind and ximcentroid.

A new mask combining task xmskcombine has been added to the XDIMSUM package. 
Xmskcombine combines the badpix mask, the cosmic ray mask, the holes mask,
and optionally the object mask for the previous image into a single
bad pixel mask used the the xnregistar task. The xnregistar task no
longer performs the mask combining step it used to.

New Algorithms

The main processing scripts xmosaic, xfirstpass, and xmaskpass can now be run
repeatedly from scratch  without requiring the user to delete any intermediate
files. It has also been made simpler to restart these scripts at an intermediate
point in the processing.

The mask deregistration task maskdereg now permits the user to create individual
object masks which are a combination of the current mask and the N previous
ones. This feature is useful in cases where the detector retains significant
memory of previous exposures.

The image and mask statistics computation parameters used by the sky
subtraction and cosmic ray removal tasks xslm and xzap, statsec, mstatsec,
maxiter, and nreject can now be set by the user. Their default values are now
"", "", 20, and 3.0 respectively, instead of being fixed at the values "", "",
10, and 5.0.

The maskstat task now outputs the computed mask statistics to the output
parameters mean, msigma, median, and mmode in the same manner as the iterstat
itask does.

The first pass image combining step performed by the xmosaic or xfirstpass
tasks now includes an option for doing fractional pixel shifts.

The mask pass image combining step performed by the xmosaic or xmaskpass tasks
now includes an option for doing image magnification using bilinear
interpolation rather than block replication. This means that non-integer
magnification factors are supported.

Internal Changes

Calls to existing IRAF tasks have been reviewed to make sure that all the task
parameters are set in order to avoid unpleasant surprises if these parameters
are not set at the expected defaults.

Complicated image operations requiring several steps have been replaced by a
single call to the imexpr task where appropriate.

The image registration and combining step has been rewritten to use a new
version of the imcombine task called xcombine which does not suffer from the
number of open file limit and has better support for pixel masks. The
registration should be much faster in most cases.

The sections, fileroot, imgets, minmax, iterstat, and maskstat tasks which
return values to their parameters have been cached so that XDIMSUM tasks will
work correctly in the background.

On normal task termination there are now no temporary files or images left
either in the tmp$ directory  or in the current working directory.
