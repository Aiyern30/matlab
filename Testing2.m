clc; clear; close all;

% Read the input image
img = imread('C:\Users\ianbi\Desktop\MATLAB\Preprocessing\Car\ProtonX50.jpg'); % Replace with your image path
figure('Name', 'Original Image'); imshow(img);
title('Original Image');

% Step 1: Convert to grayscale
gray = rgb2gray(img);
figure('Name', 'Grayscale'); imshow(gray);
title('Grayscale Image');

% Step 2: Enhance contrast
enhanced = imadjust(gray);
figure('Name', 'Enhanced'); imshow(enhanced);
title('Enhanced Image');

% Step 3: Apply bilateral filter to reduce noise while preserving edges
% This is crucial for license plate detection
filtered = imbilatfilt(enhanced);
figure('Name', 'Filtered'); imshow(filtered);
title('Filtered Image');

% Step 4: Apply Sobel edge detection for better edge representation
edge_img = edge(filtered, 'sobel');
figure('Name', 'Edge Detection'); imshow(edge_img);
title('Edge Detection');

% Step 5: Dilate the edges to connect nearby edges
se = strel('rectangle', [3, 3]);
dilated = imdilate(edge_img, se);
figure('Name', 'Dilated'); imshow(dilated);
title('Dilated Edges');

% Step 6: Find connected components
% Malaysian license plates typically have a rectangular shape
% with a specific aspect ratio (around 4:1)
[labeled, numObjects] = bwlabel(dilated);
stats = regionprops(labeled, 'BoundingBox', 'Area', 'Orientation', 'MajorAxisLength', 'MinorAxisLength');

% Step 7: Filter regions based on Malaysian license plate characteristics
figure('Name', 'Candidate Regions'); imshow(img); hold on;
plate_candidates = [];

for i = 1:numObjects
    bbox = stats(i).BoundingBox;
    w = bbox(3);
    h = bbox(4);
    area = stats(i).Area;
    orientation = stats(i).Orientation;
    aspect_ratio = w / h;
    
    % Filter criteria specific to Malaysian license plates
    % Most Malaysian license plates have an aspect ratio between 2:1 and 5:1
    % They are relatively horizontal (low orientation angle)
    % They have a reasonable size in the image
    if (aspect_ratio > 2 && aspect_ratio < 5) && ...
            (abs(orientation) < 20) && ...
            (area > 1000 && area < 50000) && ...
            (w > 60 && h > 15) && (w < width(img)/2)
        
        rectangle('Position', bbox, 'EdgeColor', 'r', 'LineWidth', 2);
        plate_candidates = [plate_candidates; bbox];
    end
end
hold off;
title('License Plate Candidates');

if isempty(plate_candidates)
    disp('No license plate candidates found!');
    
    % Try more relaxed criteria
    disp('Trying more relaxed criteria...');
    figure('Name', 'Relaxed Criteria'); imshow(img); hold on;
    
    for i = 1:numObjects
        bbox = stats(i).BoundingBox;
        w = bbox(3);
        h = bbox(4);
        aspect_ratio = w / h;
        
        % Relaxed criteria
        if (aspect_ratio > 1.5 && aspect_ratio < 7) && (w > 40 && h > 10)
            rectangle('Position', bbox, 'EdgeColor', 'y', 'LineWidth', 2);
            plate_candidates = [plate_candidates; bbox];
        end
    end
    hold off;
    title('Relaxed License Plate Candidates');
end

% Sort candidates by area (typically the license plate has a significant area)
if ~isempty(plate_candidates)
    areas = plate_candidates(:,3) .* plate_candidates(:,4);
    [~, idx] = sort(areas, 'descend');
    plate_candidates = plate_candidates(idx,:);
end

% Process each potential plate region
for i = 1:min(3, size(plate_candidates, 1))  % Analyze top 3 candidates
    bbox = plate_candidates(i,:);
    
    % Extract the license plate region
    plate_img = imcrop(img, bbox);
    
    % Convert to grayscale if it's not already
    if size(plate_img, 3) == 3
        plate_gray = rgb2gray(plate_img);
    else
        plate_gray = plate_img;
    end
    
    % IMPROVED PLATE PREPROCESSING FOR BETTER CHARACTER RECOGNITION
    
    % 1. Apply CLAHE (Contrast Limited Adaptive Histogram Equalization)
    % This works better than standard imadjust for uneven lighting
    plate_gray = adapthisteq(plate_gray, 'ClipLimit', 0.02);
    
    % 2. Apply Gaussian blur to reduce noise
    plate_gray = imgaussfilt(plate_gray, 0.8);
    
    % 3. Sharpen the image to enhance character edges
    plate_gray = imsharpen(plate_gray, 'Radius', 1, 'Amount', 1);
    
    % 4. Improve binarization with Otsu's method
    plate_bw = imbinarize(plate_gray);
    
    % 5. Check if inversion is needed (dark text on light background vs light text on dark background)
    if mean2(plate_bw) > 0.5
        plate_bw = ~plate_bw;
    end
    
    % 6. Apply morphological operations to clean the binary image
    % Remove small objects (noise)
    plate_bw = bwareaopen(plate_bw, 30);
    
    % 7. Fill small holes in characters
    plate_bw = imfill(plate_bw, 'holes');
    
    % 8. Additional morphological operations to improve character shape
    se_erode = strel('disk', 1);
    plate_bw = imerode(plate_bw, se_erode);
    se_dilate = strel('disk', 1);
    plate_bw = imdilate(plate_bw, se_dilate);
    
    % Display processing stages for this plate candidate
    figure('Name', ['Plate Candidate ' num2str(i)]);
    subplot(2,2,1); imshow(plate_img); title('Extracted Region');
    subplot(2,2,2); imshow(plate_gray); title('Enhanced Grayscale');
    subplot(2,2,3); imshow(plate_bw); title('Binary');
    
    % IMPROVED CHARACTER SEGMENTATION
    
    % Find connected components in the binary image
    [char_labeled, numChars] = bwlabel(plate_bw);
    char_stats = regionprops(char_labeled, 'BoundingBox', 'Area', 'Extent', 'Solidity');
    
    % Filter character candidates with more precise criteria
    char_candidates = [];
    for j = 1:numChars
        char_bbox = char_stats(j).BoundingBox;
        char_w = char_bbox(3);
        char_h = char_bbox(4);
        char_ratio = char_h / char_w;
        char_area = char_stats(j).Area;
        char_extent = char_stats(j).Extent;
        char_solidity = char_stats(j).Solidity;  % More robust shape measure
        
        % Refined criteria for Malaysian license plate characters
        if (char_ratio >= 1.2 && char_ratio <= 5) && ...
                (char_h >= height(plate_bw)*0.3 && char_h <= height(plate_bw)*0.9) && ...
                (char_w >= 5 && char_w <= width(plate_bw)/4) && ...
                (char_extent >= 0.3) && ...
                (char_solidity >= 0.6)  % Solidity helps distinguish characters from noise
            char_candidates = [char_candidates; char_bbox];
        end
    end
    
    % Sort characters from left to right
    if ~isempty(char_candidates)
        [~, idx] = sort(char_candidates(:,1));
        char_candidates = char_candidates(idx,:);
        
        % IMPROVED CHARACTER MERGING (for broken characters)
        merged_char_candidates = merge_close_characters(char_candidates, width(plate_bw));
        
        % Display characters
        subplot(2,2,4); imshow(plate_img); hold on;
        title('Segmented Characters');
        
        recognized_chars = cell(1, size(merged_char_candidates, 1));
        
        % IMPROVED CHARACTER RECOGNITION
        for j = 1:size(merged_char_candidates, 1)
            char_bbox = merged_char_candidates(j,:);
            rectangle('Position', char_bbox, 'EdgeColor', 'g', 'LineWidth', 1);
            
            % Extract character
            char_img = imcrop(plate_bw, char_bbox);
            
            % Resize character for better recognition (standardize size)
            char_img = imresize(char_img, [42 28]);
            
            % Add padding to avoid edge effects
            char_img = padarray(char_img, [4 4], 0);
            
            % Try OCR if available
            if license('test', 'Text_Analytics_Toolbox')
                try
                    % Use customized OCR settings for license plates
                    results = ocr(char_img, 'TextLayout', 'Character', ...
                        'CharacterSet', '0123456789ABCDEFGHJKLMNPRSTUVWXYZ', ...
                        'Language', 'alphanumeric');
                    
                    if ~isempty(results.Text)
                        recognized_text = strtrim(results.Text);
                        recognized_text = fix_common_ocr_errors(recognized_text);
                        recognized_chars{j} = recognized_text;
                        
                        % Display recognized character
                        text(char_bbox(1), char_bbox(2)-10, recognized_text, 'Color', 'r', 'FontWeight', 'bold');
                    else
                        recognized_chars{j} = '?';
                    end
                catch
                    recognized_chars{j} = '?';
                end
            else
                % ALTERNATIVE RECOGNITION METHOD WHEN OCR IS NOT AVAILABLE
                % Using template matching or simple shape analysis
                
                % Create a new figure for each character
                figure('Name', ['Character ' num2str(j)]);
                imshow(char_img);
                title(['Character ' num2str(j)]);
                
                % Compute basic shape features for simple classification
                features = extract_char_features(char_img);
                recognized_chars{j} = classify_by_shape(features);
                
                % Display the estimated character
                text(char_bbox(1), char_bbox(2)-10, recognized_chars{j}, 'Color', 'r', 'FontWeight', 'bold');
            end
            
            % Label character position
            text(char_bbox(1), char_bbox(2)+char_bbox(4)+5, num2str(j), 'Color', 'b');
        end
        hold off;
        
        % IMPROVED PLATE TEXT FORMATION
        
        % Combine characters to form plate text
        plate_text = strjoin(recognized_chars, '');
        plate_text = regexprep(plate_text, '[^0-9A-Z]', ''); % Clean up non-alphanumeric
        
        if ~isempty(plate_text)
            % Post-process the recognized text to match Malaysian plate format
            plate_text = post_process_plate_text(plate_text);
            
            % Identify state with improved confidence
            [state, confidence] = identify_malaysian_state_improved(plate_text);
            
            % Display final result for this candidate
            figure('Name', ['Plate Result ' num2str(i)]);
            imshow(img);
            hold on;
            rectangle('Position', bbox, 'EdgeColor', 'g', 'LineWidth', 3);
            text(bbox(1), bbox(2)-20, ['Plate: ' plate_text], ...
                'FontSize', 14, 'Color', 'r', 'FontWeight', 'bold', ...
                'BackgroundColor', [1 1 1 0.7]);
            text(bbox(1), bbox(2)-50, ['State: ' state ' (Confidence: ' num2str(confidence) '%)'], ...
                'FontSize', 14, 'Color', 'b', 'FontWeight', 'bold', ...
                'BackgroundColor', [1 1 1 0.7]);
            hold off;
            
            disp(['Candidate ' num2str(i) ' - Detected Plate: ' plate_text]);
            disp(['Candidate ' num2str(i) ' - Detected State: ' state ' (Confidence: ' num2str(confidence) '%)']);
        else
            disp(['Candidate ' num2str(i) ' - No characters recognized']);
        end
    else
        disp(['Candidate ' num2str(i) ' - No valid characters found']);
    end
end

% Function to merge characters that are likely part of the same character but got split
function merged_candidates = merge_close_characters(char_candidates, plate_width)
if isempty(char_candidates)
    merged_candidates = [];
    return;
end

% Sort by x position
[~, idx] = sort(char_candidates(:,1));
sorted_candidates = char_candidates(idx,:);

% Initialize with the first candidate
merged_candidates = sorted_candidates(1,:);
current_index = 1;

% Define proximity threshold (adjust based on plate size)
proximity_threshold = plate_width * 0.03;  % 3% of plate width

for i = 2:size(sorted_candidates, 1)
    current_bbox = sorted_candidates(i,:);
    prev_bbox = merged_candidates(current_index,:);
    
    % Calculate horizontal distance between bounding boxes
    x_distance = current_bbox(1) - (prev_bbox(1) + prev_bbox(3));
    
    % Check vertical overlap
    y_overlap = max(0, min(prev_bbox(2) + prev_bbox(4), current_bbox(2) + current_bbox(4)) - max(prev_bbox(2), current_bbox(2)));
    vertical_overlap_ratio = y_overlap / max(prev_bbox(4), current_bbox(4));
    
    % If boxes are very close horizontally and have significant vertical overlap, they might be parts of the same character
    if x_distance < proximity_threshold && vertical_overlap_ratio > 0.3
        % Merge the bounding boxes
        min_x = min(prev_bbox(1), current_bbox(1));
        min_y = min(prev_bbox(2), current_bbox(2));
        max_x = max(prev_bbox(1) + prev_bbox(3), current_bbox(1) + current_bbox(3));
        max_y = max(prev_bbox(2) + prev_bbox(4), current_bbox(2) + current_bbox(4));
        
        merged_width = max_x - min_x;
        merged_height = max_y - min_y;
        
        % Replace the previous box with the merged box
        merged_candidates(current_index,:) = [min_x, min_y, merged_width, merged_height];
    else
        % Add as a new character
        current_index = current_index + 1;
        merged_candidates(current_index,:) = current_bbox;
    end
end
end

% Function to fix common OCR errors in license plates
function corrected_text = fix_common_ocr_errors(text)
% Common OCR mistakes in license plates
corrected_text = text;
corrected_text = strrep(corrected_text, 'O', '0');  % Letter O to number 0
corrected_text = strrep(corrected_text, 'I', '1');  % Letter I to number 1
corrected_text = strrep(corrected_text, 'Z', '2');  % Letter Z to number 2
corrected_text = strrep(corrected_text, 'S', '5');  % Letter S to number 5
corrected_text = strrep(corrected_text, 'B', '8');  % Letter B to number 8
corrected_text = strrep(corrected_text, 'G', '6');  % Letter G to number 6
corrected_text = strrep(corrected_text, 'D', '0');  % Letter D to number 0
end

% Function to extract simple shape features for character recognition when OCR is unavailable
function features = extract_char_features(char_img)
% Compute basic shape features that can help distinguish characters
features = struct();

% Size
[height, width] = size(char_img);
features.aspect_ratio = height / width;

% Pixel density (ratio of foreground pixels)
features.density = sum(char_img(:)) / numel(char_img);

% Horizontal and vertical projections
features.h_projection = sum(char_img, 1) / height;
features.v_projection = sum(char_img, 2)' / width;

% Central moments (simple shape descriptors)
[y, x] = ndgrid(1:height, 1:width);
fg_pixels = char_img > 0;
if sum(fg_pixels(:)) > 0
    features.center_x = sum(x(fg_pixels)) / sum(fg_pixels(:));
    features.center_y = sum(y(fg_pixels)) / sum(fg_pixels(:));
else
    features.center_x = width/2;
    features.center_y = height/2;
end

% Quarters density (divide image into 4 quadrants and compute density of each)
half_h = ceil(height/2);
half_w = ceil(width/2);
features.q1_density = sum(sum(char_img(1:half_h, 1:half_w))) / (half_h * half_w);
features.q2_density = sum(sum(char_img(1:half_h, half_w+1:end))) / (half_h * (width-half_w));
features.q3_density = sum(sum(char_img(half_h+1:end, 1:half_w))) / ((height-half_h) * half_w);
features.q4_density = sum(sum(char_img(half_h+1:end, half_w+1:end))) / ((height-half_h) * (width-half_w));

% Holes (useful for differentiating 0, 8, 6, 9, etc.)
features.holes = count_holes(char_img);
end

% Function to count holes in binary image (useful for character recognition)
function num_holes = count_holes(binary_img)
% Count the number of holes in the binary image
% A hole is a connected region of 0s surrounded by 1s

% Invert the image to make holes foreground
inverted = ~binary_img;

% Label connected components in the inverted image
[labeled, num_objects] = bwlabel(inverted);

% Count holes (exclude the "background" which is typically the largest component)
if num_objects > 1
    component_sizes = zeros(1, num_objects);
    for i = 1:num_objects
        component_sizes(i) = sum(labeled(:) == i);
    end
    
    % Find the largest component (assumed to be background)
    [~, bg_idx] = max(component_sizes);
    
    % Count non-background components that are fully enclosed
    num_holes = 0;
    for i = 1:num_objects
        if i ~= bg_idx
            % Check if this component is fully enclosed (a true hole)
            % by checking if it touches the image border
            component = labeled == i;
            if ~any(component(1,:)) && ~any(component(end,:)) && ...
                    ~any(component(:,1)) && ~any(component(:,end))
                num_holes = num_holes + 1;
            end
        end
    end
else
    num_holes = 0;
end
end

% Function to classify characters based on shape features when OCR is unavailable
function char_class = classify_by_shape(features)
% Simple rules-based classifier for license plate characters
% This is a fallback when OCR is not available

% Numbers classification
if features.holes == 1
    if features.aspect_ratio < 1.5 && features.density > 0.4
        char_class = '0';  % Zero is typically round with one hole
    elseif features.q1_density > 0.4 && features.q4_density > 0.4
        char_class = '8';  % Eight typically has high density in top and bottom
    elseif features.q1_density > 0.4 && features.q3_density > 0.4
        char_class = '6';  % Six has density on left side
    elseif features.q2_density > 0.4 && features.q4_density > 0.4
        char_class = '9';  % Nine has density on right side
    else
        char_class = '0';  % Default to zero for any character with one hole
    end
elseif features.holes == 0
    if features.aspect_ratio > 3
        char_class = '1';  % One is typically tall and thin
    elseif features.density < 0.3
        char_class = '7';  % Seven typically has low density
    elseif features.v_projection(1) > 0.7 && mean(features.v_projection(end-3:end)) > 0.7
        char_class = '5';  % Five has high density at top and bottom
    elseif mean(features.v_projection(1:3)) > 0.7
        char_class = '3';  % Three has high density at top
    elseif mean(features.h_projection(1:3)) > 0.7 && mean(features.h_projection(end-3:end)) > 0.7
        char_class = '2';  % Two has high density at left and right
    elseif features.q1_density > 0.5 && features.q4_density > 0.5
        char_class = '4';  % Four has high density in upper left and lower right
    else
        % Default for letters (most common first letters in Malaysian plates)
        if features.aspect_ratio > 2
            char_class = 'W';  % Common first letter in KL plates
        else
            char_class = 'B';  % Common first letter in Selangor plates
        end
    end
elseif features.holes == 2
    char_class = '8';  % Eight sometimes detected as having 2 holes
else
    % Default for unknown
    char_class = 'X';
end
end

% Function to post-process plate text to match Malaysian plate format
function processed_text = post_process_plate_text(plate_text)
if isempty(plate_text)
    processed_text = '';
    return;
end

% Malaysian license plates typically have 1-3 letters followed by 1-4 numbers
% Extract all letters and numbers
letters = '';
numbers = '';
current_section = 'letters'; % Start with letters

for i = 1:length(plate_text)
    char = plate_text(i);
    
    if isstrprop(char, 'alpha')
        if strcmp(current_section, 'numbers')
            % If we've already seen numbers and now find a letter,
            % it's likely an OCR error (e.g., 'O' should be '0')
            numbers = [numbers '0'];
        else
            letters = [letters char];
        end
    elseif isstrprop(char, 'digit')
        current_section = 'numbers'; % Once we hit numbers, all following chars should be numbers
        numbers = [numbers char];
    end
end

% Validate the result
if length(letters) > 3
    % Too many letters, keep only first 3
    letters = letters(1:3);
elseif isempty(letters)
    % No letters found, could be an error or commercial vehicle
    letters = 'X'; % Placeholder
end

if length(numbers) > 4
    % Too many numbers, keep only first 4
    numbers = numbers(1:4);
elseif isempty(numbers)
    % No numbers found, could be an error
    numbers = '0000'; % Placeholder
end

processed_text = [letters numbers];
end

% Improved function to identify Malaysian state from license plate prefix with confidence level
function [state, confidence] = identify_malaysian_state_improved(plate_text)
if isempty(plate_text)
    state = 'Unknown';
    confidence = 0;
    return;
end

% Get first non-digit characters (prefix)
prefix = '';
for i = 1:min(3, length(plate_text))
    if ~isstrprop(plate_text(i), 'digit')
        prefix = [prefix, plate_text(i)];
    else
        break;
    end
end

% Convert to uppercase
prefix = upper(prefix);

% Map prefix to Malaysian states with confidence levels
switch prefix
    case 'A'
        state = 'Perak';
        confidence = 95;
    case 'B'
        state = 'Selangor';
        confidence = 95;
    case 'C'
        state = 'Pahang';
        confidence = 95;
    case 'D'
        state = 'Kelantan';
        confidence = 95;
    case 'J'
        state = 'Johor';
        confidence = 95;
    case 'K'
        state = 'Kedah';
        confidence = 95;
    case 'M'
        state = 'Melaka';
        confidence = 95;
    case 'N'
        state = 'Negeri Sembilan';
        confidence = 95;
    case 'P'
        state = 'Penang';
        confidence = 95;
    case 'R'
        state = 'Perlis';
        confidence = 95;
    case 'T'
        state = 'Terengganu';
        confidence = 95;
    case 'V'
        state = 'ASEAN';
        confidence = 90;
    case 'W'
        state = 'Kuala Lumpur';
        confidence = 95;
    case 'S'
        state = 'Sabah';
        confidence = 95;
    case 'Q'
        state = 'Sarawak';
        confidence = 95;
    case {'KV', 'BL', 'DCA'}
        state = 'Federal Territories';
        confidence = 90;
    case {'VF'}
        state = 'Pahang (Special Series)';
        confidence = 85;
    case {'WA', 'WB', 'WC', 'WD'}
        state = 'Kuala Lumpur';
        confidence = 90;
        % Handle common OCR errors
    case {'0'} % Could be 'D' (Kelantan) misread as '0'
        state = 'Kelantan';
        confidence = 70;
    case {'8'} % Could be 'B' (Selangor) misread as '8'
        state = 'Selangor';
        confidence = 70;
    case {'L'} % Could be 'J' (Johor) or 'W' (KL) misread
        state = 'Johor/Kuala Lumpur';
        confidence = 50;
    otherwise
        state = 'Unknown';
        confidence = 0;
        
        % Check for partial matches for improved robustness
        if length(prefix) > 0
            first_char = prefix(1);
            switch first_char
                case 'W'
                    state = 'Kuala Lumpur';
                    confidence = 60;
                case 'B'
                    state = 'Selangor';
                    confidence = 60;
                case 'J'
                    state = 'Johor';
                    confidence = 60;
                case 'K'
                    state = 'Kedah';
                    confidence = 60;
                case 'P'
                    state = 'Penang';
                    confidence = 60;
                case 'A'
                    state = 'Perak';
                    confidence = 60;
            end
        end
end
end