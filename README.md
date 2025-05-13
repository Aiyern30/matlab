# License Plate Recognition (LPR) and State Identification System (SIS)

## Project Overview

This project implements a Malaysian vehicle license plate recognition system capable of detecting license plates, extracting the text, and identifying the registration state based on the first character. The system is built as a MATLAB application with a graphical user interface that allows users to select and analyze images of different vehicle types.

## Developers

- Wong Wei Fong (TP065467)
- Ian Gan Jian Hao (TP064373)

## Features

- Recognition of license plates from various vehicle types (Car, Bus, Boat, Lorry, Taxi)
- Extraction of license plate text using OCR (Optical Character Recognition)
- Identification of Malaysian state/region based on the first character
- Interactive GUI with image preview and analysis results display
- Support for multiple image formats (JPG, PNG)

## System Requirements

- MATLAB R2019b or newer
- Image Processing Toolbox
- Computer Vision Toolbox
- Text Analytics Toolbox (for OCR functionality)

## Usage Instructions

1. Launch the application in MATLAB
2. Select a vehicle category using the toggle buttons (Car, Bus, Boat, Lorry, Taxi)
3. Choose a sample image from the dropdown menu
4. Click "Analyse" to process the image
5. View the results in the corresponding fields:
   - Recognized Car Plate: The full license plate text
   - First Character: The first character of the license plate
   - Vehicle State/Characteristics: The Malaysian state or vehicle type identification

## Technical Implementation

### Image Processing Pipeline

The system implements a comprehensive image processing pipeline to achieve accurate license plate recognition:

1. **Image Loading**: The original image is loaded and displayed
2. **Grayscale Conversion**: RGB to grayscale conversion simplifies processing
3. **Contrast Enhancement**: Improves visibility of plate features
4. **Edge Detection**: Identifies potential plate boundaries
5. **Morphological Operations**: Enhances edges and regions
6. **Region Analysis**: Identifies candidate plate regions based on geometric properties
7. **Plate Cropping**: Extracts the license plate region
8. **Character Recognition**: Performs OCR on the plate region
9. **State Identification**: Maps the first character to Malaysian states
10. **Result Visualization**: Displays results with bounding boxes and text overlay

### Key Techniques Used

#### Grayscale Conversion

- **Function**: `rgb2gray()`
- **Technique**: Color space conversion from RGB to Grayscale
- **Justification**: Simplifies the image by eliminating color information while preserving structure and contrast. Makes license plate elements more noticeable and reduces data size for processing.

#### Contrast Enhancement

- **Function**: `imadjust()`
- **Technique**: Histogram stretching / Intensity adjustment
- **Justification**: Increases intensity differences between background and foreground elements to make plate characters more readable under various lighting conditions.

#### Edge Detection

- **Function**: `edge(grayImg, 'Canny', [0.1 0.3])`
- **Technique**: Canny Edge Detection
- **Justification**: Superior edge detection method with multi-stage filtering process. Distinguishes rectangular plate boundaries and character contours while minimizing false edges from noise.

#### Morphological Processing

- **Function**: `imclose()` with `strel('rectangle', [3,15])`
- **Technique**: Morphological Closing
- **Justification**: Improves region quality before bounding box detection by connecting nearby edges that may belong to the same object.

#### Region Properties & Filtering

- **Function**: `regionprops()`
- **Technique**: Geometric property analysis (area, aspect ratio, extent)
- **Justification**: Calculates properties of detected regions to filter out non-plate areas. Ensures only candidates with plate-like characteristics (rectangular shape, appropriate aspect ratio) are retained.

#### Plate Cropping and ROI Extraction

- **Function**: `imcrop()`
- **Technique**: Region of Interest (ROI) Extraction
- **Justification**: Crops the identified license plate region to focus processing on relevant areas only, reducing computation burden and improving accuracy.

#### Binarization for OCR

- **Function**: `imbinarize()`
- **Technique**: Adaptive Thresholding
- **Justification**: Adapts to local image regions to properly isolate characters from background under varying lighting conditions.

#### Noise Reduction

- **Function**: `bwareaopen()`, `medfilt2()`
- **Technique**: Median Filtering and Small Object Removal
- **Justification**: Removes small spurious artifacts and smooths the binarized image without blurring character edges, preparing the image for more accurate OCR.

#### Character Segmentation

- **Function**: `imcrop()` for sub-region extraction, `imsharpen()`
- **Technique**: Region Isolation & Sharpening
- **Justification**: Extracts and enhances the first character for more accurate recognition, essential for state identification.

#### Optical Character Recognition

- **Function**: `ocr(...)`
- **Technique**: Template Matching with Character Set Limitation
- **Justification**: Extracts alphanumeric characters with constraints to valid license plate symbols, reducing false positives from irrelevant patterns.

#### State Detection Mapping

- **Function**: `containers.Map()`
- **Technique**: Lookup Table
- **Justification**: Maps first characters to Malaysian states using a predefined lookup table, ensuring accurate state identification based on official registration rules.

## Malaysian License Plate State Identification

The system identifies Malaysian states based on the first character of the license plate:

| First Character | State/Region    |
| --------------- | --------------- |
| A               | Perak           |
| B               | Selangor        |
| C               | Pahang          |
| D               | Kelantan        |
| F               | Putrajaya       |
| H               | Taxi            |
| J               | Johor           |
| K               | Kedah           |
| L               | Labuan          |
| M               | Melaka          |
| N               | Negeri Sembilan |
| P               | Penang          |
| Q               | Sarawak         |
| R               | Perlis          |
| S               | Sabah           |
| T               | Terengganu      |
| U               | iM4U Sentral    |
| V               | Kuala Lumpur    |
| W               | Kuala Lumpur    |
| Z               | Military        |

## Future Improvements

- Enhanced robustness for plates with severe damage or dirt
- Support for non-standard plate formats
- Real-time processing capability for video streams
- Integration with database systems for vehicle tracking
- Deep learning approach for improved character recognition accuracy

## References

- Digital Image Processing Using MATLAB, 3rd Edition
- MATLAB Image Processing Toolbox Documentation
- Road Transport Department Malaysia (JPJ) Official Guidelines
