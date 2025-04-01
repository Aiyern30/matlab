clc; clear; close all;

% Read the input image
img = imread('C:\Users\ianbi\Desktop\MATLAB\Preprocessing\Car\BMW.jpg');

% Step 1: Convert to grayscale
gray_img = rgb2gray(img);

% Step 2: Apply Adaptive Thresholding for better contrast
bw_img = imbinarize(gray_img, 'adaptive', 'ForegroundPolarity', 'dark', 'Sensitivity', 0.4);

% Step 3: Apply Edge Detection (Canny)
edge_img = edge(bw_img, 'Canny');

% Step 4: Morphological Closing to Fill Gaps
se = strel('rectangle', [5,5]);
closed_img = imclose(edge_img, se);

% Step 5: Detect Connected Components (Find possible license plates)
cc = bwconncomp(closed_img);
stats = regionprops(cc, 'BoundingBox', 'Area');

% Step 6: Filter out regions based on area and aspect ratio
min_area = 1500;
max_area = 15000;
best_bbox = [];

for k = 1:length(stats)
    bbox = stats(k).BoundingBox;
    aspect_ratio = bbox(3) / bbox(4); % Width / Height
    
    if stats(k).Area > min_area && stats(k).Area < max_area && (aspect_ratio > 2 && aspect_ratio < 5)
        best_bbox = bbox;
        break; % Stop after finding the best plate candidate
    end
end

% Step 7: If a license plate is found, extract it
if ~isempty(best_bbox)
    plate_img = imcrop(gray_img, best_bbox);
    
    % Convert to binary for character segmentation
    plate_bw = imbinarize(plate_img);
    
    % Step 8: Apply Morphological Dilation to Separate Characters
    char_se = strel('rectangle', [2,2]);
    plate_dilated = imdilate(plate_bw, char_se);
    
    % Show the detected license plate
    figure; imshow(plate_dilated);
    title('Detected License Plate');
    
    % Step 9: Find Characters in the Plate
    char_cc = bwconncomp(plate_dilated);
    char_stats = regionprops(char_cc, 'BoundingBox');
    
    extracted_text = "";
    for i = 1:length(char_stats)
        char_bbox = char_stats(i).BoundingBox;
        char_img = imcrop(plate_dilated, char_bbox);
        
        % Resize characters to standard size for OCR
        char_img = imresize(char_img, [40 40]);
        
        % Display segmented characters
        figure; imshow(char_img);
        title(['Character ', num2str(i)]);
        
        % Step 10: Recognize character using OCR
        if license('test', 'Computer_Vision_Toolbox')
            char_result = ocr(char_img);
            extracted_text = extracted_text + strip(char_result.Text);
        end
    end
    
    % Display the extracted license plate text
    disp('Detected License Plate Text:');
    disp(extracted_text);
else
    disp('License plate not found.');
end
