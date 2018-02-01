function array_out = arrayresize(array_in,newsize,method)
% 
% This function works like imresize in the image processing toolbox. But it
% works on double data instead of just unsigned 8 bit integers.  And it
% works in any number of dimensions.  Just make sure that... 
% length(newsize) == ndims(array_in)
%
% Examples:
%
%     im = imread('ngc6543a.jpg'); % read an image file into a 3D RGB array (650x600 pixels)
%
%     method      = 'nearest';
%     shrunk_im   = arrayresize(im,[100 100 3]  ,method); % reduce image to 100x100 pixels
%     squeezed_im = arrayresize(im,[650 100 3]  ,method); % squeeze image to 650x100 pixels
%     stretch_im  = arrayresize(im,[650 1200 3] ,method); % squeeze image to 650x1200 pixels
%     im_cube     = arrayresize(im,[100 100 100],method); % make the array a cube
%                                                               
%     figure, image(im),          title('original'),  truesize % show the results
%     figure, image(shrunk_im),   title('shrunk'),    truesize % show the results
%     figure, image(squeezed_im), title('squeezed'),  truesize % show the results
%     figure, image(stretch_im),  title('stretched'), truesize % show the results
%
%     size(im_cube) % show size of new array
%
% I wrote this to take care of the silliness that is matlab interpolation
% functions.  I guess they are written the way they are so that scientists
% and engineers can feel like they have actually accomplished something
% after they are done using them.  (i.e. "Wow! I actually got interp3 to
% do something!  That was a lot of work.  Guess I should call it a day!")
%
% But that is not to say that this function is not silly.
% It is NOT not silly (see code).
%
% see also imresize

if nargin < 3
    method = 'linear';
end

oldsize = size(array_in);

if length(newsize) < length(oldsize)
    error('The following must be true to run arrayresize. length(newsize) == ndims(array_in)')
end


% Pad the array starts and ends in all dimensions for a more accurate estimate.
% This is tricky b/c I don't know the input dimensions.
% I am going to start making and executing commands in some loops that look
% like the following four commands but with an arbitrary number of
% dimensions.
%
% tmp(:,:,1) = array_in(:,:,1); %cmd_1
% tmp(:,:,2:oldsize(3)+1) = array_in; % cmd_2
% tmp(:,:,end+1) = array_in(:,:,end); % cmd_3
% array_in = tmp; clear tmp
%
% I'm warning you.  This is going to get ugly...

dims               = length(oldsize);
index_str_maker    = cell(1,dims);
index_str_maker(:) = {':'};
XYZ                = cell(1,dims); % for interpolation
XqYqZq             = cell(1,dims); % for interpolation
half_cube          = 0.5; % this is b/c we will just indexed by 1 below with no regard for actual units :-)
gridscale          = oldsize ./ (newsize-1);
XYZ_cmd_helper     = []; % don't even ask
XqYqZq_cmd_helper  = []; % ditto
for ii = 1:dims
    
    cmd_1_maker = index_str_maker;
    cmd_1_maker(ii) = {'1'};
    
    cmd_2_maker = index_str_maker;
    cmd_2_maker(ii) = {sprintf('2:oldsize(%s)+1',num2str(ii))};
    
    cmd_3_maker_pt1 = index_str_maker;
    cmd_3_maker_pt1(ii) = {'end+1'};
    
    cmd_3_maker_pt2 = index_str_maker;
    cmd_3_maker_pt2(ii) = {'end'};
    
    cmd_1_str     = [];
    cmd_2_str     = [];
    cmd_3_str_pt1 = [];
    cmd_3_str_pt2 = []; % I know how this looks. I'm not proud.
    for jj = 1:dims
        
        cmd_1_str     = [cmd_1_str cmd_1_maker{jj} ','];
        cmd_2_str     = [cmd_2_str cmd_2_maker{jj} ','];
        cmd_3_str_pt1 = [cmd_3_str_pt1 cmd_3_maker_pt1{jj} ','];
        cmd_3_str_pt2 = [cmd_3_str_pt2 cmd_3_maker_pt2{jj} ',']; % weeps softly on keyboard
        
    end
    
    cmd_1_str(end)     = [];
    cmd_2_str(end)     = [];
    cmd_3_str_pt1(end) = [];
    cmd_3_str_pt2(end) = []; % needed for even moar elegance
    
    cmd_1 = sprintf('tmp(%s) = array_in(%s);',cmd_1_str,cmd_1_str); % on the plus side, this code practically writes itself :-P
    cmd_2 = sprintf('tmp(%s) = array_in;',cmd_2_str);
    cmd_3 = sprintf('tmp(%s) = array_in(%s);',cmd_3_str_pt1,cmd_3_str_pt2); % you have almost reached the end of this nonsense
    
    eval(cmd_1)
    eval(cmd_2)
    eval(cmd_3) % just call me Dr. Eval
    
    array_in = tmp; 
    clear tmp
    
    XYZ(ii)    = {0:oldsize(ii)+1}; % zero and +1 because we padded the array starts
    XqYqZq(ii) = {half_cube:gridscale(ii):oldsize(ii)+half_cube}; % will interpolate on centers instead of in between slices
    
    % while we are at it go ahead and construct the commands necessary to
    % do the interpolation below
    XYZ_cmd_helper    = [XYZ_cmd_helper sprintf('XYZ{%s}'      ,num2str(ii)) ','];
    XqYqZq_cmd_helper = [XqYqZq_cmd_helper sprintf('XqYqZq{%s}',num2str(ii)) ','];
    
end

% Remember when I said you were almost finished with the nonesense? I lied.
XYZ_cmd_helper(end)    = [];
XqYqZq_cmd_helper(end) = []; % again, for the elegance

% so now we will basically construct the following 3 commands with however
% many inputs the user asked for
% [X,Y,Z]    = ndgrid(Y,X,Z);
% [Xq,Yq,Zq] = ndgrid(Yq,Xq,Zq);
% array_out  = interpn(X,Y,Z,array_in,Xq,Yq,Zq,method);

cmd_1 = sprintf('[%s] = ndgrid(%s);',XYZ_cmd_helper,XYZ_cmd_helper);
cmd_2 = sprintf('[%s] = ndgrid(%s);',XqYqZq_cmd_helper,XqYqZq_cmd_helper);
cmd_3 = sprintf('array_out = interpn(%s,array_in,%s,method);',XYZ_cmd_helper,XqYqZq_cmd_helper);

eval(cmd_1)
eval(cmd_2)
eval(cmd_3) % Dr. Eval (never gets old)


% Right.  So... let's just pretend none of this actually happened.
