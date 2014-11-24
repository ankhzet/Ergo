unit GraphicStrings;
interface

resourcestring
  // image file descriptions
  gesAllImages = 'Все изображения';
  gesRegistration = 'Попытка харегистрировать %s файлы (дважды).';
  
  gesBitmaps = 'Windows битовые карты';
  gesRLEBitmaps = 'Run length закодированные битовые карты Windows';
  gesDIBs = 'Битовые карты Windows, независимые от устройства';
  gesIcons = 'Пиктограммы Windows';
  gesMetaFiles = 'Метафайлы Windows';
  gesEnhancedMetaFiles = 'Расширенные метафайлы Windows';
  gesJPGImages = 'Изображения JPG';
  gesJFIFImages = 'JFIF images';
  gesJPEImages = 'JPE images';
  gesJPEGImages = 'Изображения JPEG';
  gesTruevision = 'Изображения Truevision';
  gesTIFF = 'Изображения формата TIFF';
  gesMacTIFF =  'Изображения TIFF для Macintosh';
  gesPCTIF = 'PC TIF изображения';
  gesGFIFax = 'GFI fax images';
  gesSGI = 'Изображения SGI';
  gesSGITrueColor = 'Полноцветные изображения SGI';
  gesZSoft = 'Изображения ZSoft Paintbrush';
  gesZSoftWord = 'Снимки экрана Word 5.x';
  gesAliasWaveFront = 'Изображения Alias/Wavefront';
  gesSGITrueColorAlpha = 'Полноцветные изображения SGI с альфа-каналом';
  gesSGIMono = 'Чёрно-белые изображения SGI';
  gesPhotoshop = 'Изображения Photoshop';
  gesPortable = 'Изображения Portable map';
  gesPortablePixel = 'Изображения Portable pixel map';
  gesPortableGray = 'Изображения Portable gray map';
  gesPortableMono = 'Изображения Portable bitmap';
  gesAutoDesk = 'Изображения Autodesk';
  gesKodakPhotoCD = 'Изображения Kodak Photo-CD';
  gesCompuserve = 'Изображения CompuServe';
  gesHalo = 'Изображения Dr. Halo';
  gesPaintShopPro = 'Изображения Paintshop Pro';
  gesPortableNetworkGraphic = 'Изображения Portable network graphic (PNG)';

  // image specific error messages
  gesInvalidImage = 'Невозможно загружить изображение. Неправильный или неподдерживаемый формат изображения %s.';
  gesInvalidColorFormat = 'Неправильный формат цвета в файле %s.';
  gesStreamReadError = 'Ошибка чтения из потока в файле %s.';
  gesUnsupportedImage = 'Невозможно загружить изображение. Неподдерживаемый формат изображения %s.';
  gesUnsupportedFeature = 'Невозможно загружить изображение. %s не поддерживается для файлов %s.';
  gesInvalidCRC = 'Невозможно загружить изображение. Ошибка CRC найдена в файлы %s.';
  gesCompression = 'Невозможно загружить изображение. Ошибка сжатия в файле %s.';
  gesExtraCompressedData = 'Невозможно загружить изображение. Дополнительные данные найдены в файле %s.';
  gesInvalidPalette = 'Невозможно загружить изображение. Неправильная палитра в файле %s.';

  // features (usually used together with unsupported feature string)
  gesCompressionScheme = 'Схема сжатия ';
  gesPCDImageSize = 'Размеры изображения, отличные от Base16, Base4 or Base ';
  gesRLAPixelFormat = 'Форматы изображений, отличные от RGB and RGBA ';
  gesPSPFileType = 'Версии формата файла, отличные от 3й или 4й ';

  // errors which apply only to specific image types
  gesUnknownCriticalChunk = 'Невозможно загрузить изображение PNG. Обнаружена неожиданная, но критическая ошибка.';

  // color manager error messages
  gesIndexedNotSupported = 'Конверсия между индексированными и не-индексированными форматами изображений не поддерживается.';
  gesConversionUnsupported = 'Цветовая конверсия не поддерживается. Не возможно найти правильный метод.';
  gesInvalidSampleDepth = 'Неправильная цветовая глубина. Поддерживается глубина в битах: 1, 2, 4, 8, or 16.';
  gesInvalidSubSampling = 'Subsampling value is invalid. Allowed are 1, 2 and 4.';
  gesVerticalSubSamplingError = 'Vertical subsampling value must be <= horizontal subsampling value.';
	gesInvalidPixelDepth = 'Глубина изображения в битах не подходит к текущей цветовой схеме.';

  // progress strings
  gesPreparing = 'Preparing...';
  gesLoadingData = 'Loading data...';
  gesUpsampling = 'Upsampling...';
  gesTransfering = 'Transfering...';

  // compression errors
  gesLZ77Error = 'LZ77 decompression error.';
  gesJPEGEOI = 'JPEG decompression error. Unexpected end of input.';
  gesJPEGStripSize = 'Improper JPEG strip/tile size.';
  gesJPEGComponentCount = 'Improper JPEG component count.';
  gesJPEGDataPrecision = 'Improper JPEG data precision.';
  gesJPEGSamplingFactors = 'Improper JPEG sampling factors.';
  gesJPEGBogusTableField = 'Bogus JPEG tables field.';
  gesJPEGFractionalLine = 'Fractional JPEG scanline unsupported.';
  // miscellaneous
  gesWarning = 'Warning';
//----------------------------------------------------------------------------------------------------------------------

implementation

//----------------------------------------------------------------------------------------------------------------------

end.
