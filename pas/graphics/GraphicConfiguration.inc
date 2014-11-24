{$define UseLZW} // if this is not defined (default) then neither the GIF format nor the
                  // LZW compression decoder (e.g. for TIFF LZW compression) is available

{.$define SGIGraphic}             // *.bw, *.rgb, *.rgba, *.sgi images are supported
{.$define AutodeskGraphic}        // *.cel, *.pic images
{ $define TIFFGraphic}            // *.tif, *.tiff images
{.$define TargaGraphic}           // *.tga, *.vst, *.icb, *.vda, *.win images
{.$define PCXGraphic}             // *.pcx, *.pcc, *.scr images
{.$define PCDGraphic}             // *.pcd images
{.$define PortableMapGraphic}     // *.ppm, *.pgm, *.pbm images
{.$define CUTGraphic}             // *.cut (+ *.pal) images
{$define GIFGraphic}             // *.gif images
{.$define RLAGraphic}             // *.rla, *.rpf images
{.$define PhotoshopGraphic}       // *.psd, *.pdd images
{.$define PaintshopProGraphic}    // *.psp images
{$define PortableNetworkGraphic} // *.png images
{.$define EPSGraphic}             // *.eps images

// adjust dependent definitions
{$ifndef UseLZW} {$undef GIFGraphic} {$endif}
{$ifndef TIFFGraphic} {$undef EPSGraphic} {$endif}

