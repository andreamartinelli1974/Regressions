classdef Regression < handle
    %% Class to perform regression on a single timeseries using different regressors
    
    % the class has different subclasses to perform different type of
    % regresson and quality controls on the output.
    
    % the class is also the repository for some functions that are used for
    % any kind of regression (static methods)
    
    % Functions:
    
    % SimpleRegression(obj): performs a simple multilinear regression on
    % the whole available track record of the hedge fund
    
    % GetTableRet: set Output = TableRet
    % GetRegResult: set Output = RegResult
    % GetRegTests: set Output = RegTests
    % GetMTXofRegressors: set Output = MtxOfRegressors
    % GetBetas: Output=obj.RegResult.Coefficients(:,1) (beta of the simple
    % regression) this function i needed to have the same function with the
    % same kind of output for any regression class & subclass. This
    % function is used by the HedgeFund.m class to build the estimated
    % track record.
    
    % Static Methods:
    
    % matrix = getMtxPredictors(obj,numberOfTry,method): create a logical matrix
    % to chose from the regressors set the subset on wich the regression
    % will be performed. 3 different way to select the regressors:
    % 1) 'random' create numberOfTry rows with a random array of 1 & 0. no
    % constraints on the number of 1.
    % 2) 'strategy' create a matrix with a row for any strategy of the
    % indexes. E.g: a row including any "Equity" index, a row with any
    % "Credit" index and so on for any different strategy in the set
    % 3) 'correlation' for any row of the matrix, the index with the max
    % number of cross correlation over 0.75 is eliminated.
    
    % RTest = RegressionTest(LRObject): this function create a struct with
    % the main statistical tests for the regression LRObject. The imput is
    % a fitlm object.
    
    properties 
        Input;  %input struct
        % the input struct must be composed in this way:
        % obj.Input.inputdates = params.inputdates;
        %       an array of dates in matlab numbers
        % obj.Input.inputarray = params.inputarray;
        %       a matrix containig the dependent variable in first colunm
        %       and the regressors in the othres 
        % obj.Input.inputnames = params.inputnames;
        %       a cell array with the names of the X and Ys
        % obj.Input.rollingperiod = params.rollingperiod;
        %       a single number indicating the rolling window leingh in
        %       terms of number of period (eg if the number is set as 60,
        %       could be 60 days in case the series are daily or 60
        %       weeks if the series are weekly
        TableRet; %table table to be used as input for fitlm(table) regressors + dependent variable in last column
        MtxOfRegressors = []; %the logical matrix that specify wich regressors are effectively used in the regression
        RegResult; % the result of the regression. It's a LinearModel object
        RegTests; %TO BE BETTER DEFINED include the result of different test of the regression quality
        Betas; % array with: 1st clmn dates, 2nd clmn intercept, then betas 
        RollingPeriod; % rolling window's number of periods (in case the rolling period is not needed put any number)
        Output; %generic output for the GETs methods
        
    end
    
    methods
        
        function obj = Regression(params); %constructor
            
            obj.Input.inputdates = params.inputdates;
            obj.Input.inputarray = params.inputarray;
            obj.Input.inputnames = params.inputnames;
            obj.Input.rollingperiod = params.rollingperiod;
            
            % create the TableRet       
            varnames=strrep(obj.Input.inputnames,' ','_');
            obj.TableRet=array2table([obj.Input.inputdates, obj.Input.inputarray(:,2:end), obj.Input.inputarray(:,1),],'VariableNames',['date',varnames(2:end),varnames(1)]);
            
        end 
        
        function SimpleRegression(obj);
            
            obj.RegResult = fitlm(obj.TableRet(:,2:end));
            obj.RegTests = obj.RegressionTest(obj.RegResult);
            obj.MtxOfRegressors = ones(1,size(obj.TableRet,2)-2);
            obj.Betas=obj.RegResult.Coefficients.Estimate';
            k=find(abs(obj.Betas)<1e-9);
            obj.Betas(k)=0;
            obj.Betas=array2table([obj.TableRet.date(end),obj.Betas],'VariableNames',['Dates','Intercept',{obj.TableRet.Properties.VariableNames{2:end-1}}]);
        end 
        
        function SimpleConstrainedRegression(obj,LogicalMTX)
            
            SCRobj=HFSimpleConstrReg(obj.Input);
            SCRobj.SimpleRegConstr(LogicalMTX);
            obj.MtxOfRegressors = LogicalMTX;
            obj.RegResult = SCRobj.RegResult;
            obj.RegTests = SCRobj.RegTests;
            obj.Betas= SCRobj.Betas;
            
        end 
        
        function RollingRegression(obj)
            
            RRobj=HFRollingReg(obj.Input);
            RRobj.RollingReg;
            obj.MtxOfRegressors = RRobj.MtxOfRegressors;
            obj.RegResult = RRobj.RegResult;
            obj.RegTests = RRobj.RegTests;
            obj.Betas= RRobj.Betas;
            obj.RollingPeriod = RRobj.RollingPeriod;
        end
        
        function ConstrainedRollingRegression(obj,LogicalMTX)
            
            RRobj=HFRollingReg(obj.Input);
            RRobj.ConRollReg(LogicalMTX);
            obj.MtxOfRegressors = LogicalMTX;
            obj.RegResult = RRobj.RegResult;
            obj.RegTests = RRobj.RegTests;
            obj.Betas= RRobj.Betas;
            obj.RollingPeriod = RRobj.RollingPeriod;
        end
        
        % Get Functions, to access different properties of the class
        
        function GetTableRet(obj)
            obj.Output = obj.TableRet;
        end
        
        function GetRegResult(obj)
            obj.Output = obj.RegResult;
        end
        
        function GetRegTests(obj)
            obj.Output = obj.RegTests;
        end
        
        function GetMtxOfRegressors(obj)
            obj.Output = obj.MtxOfRegressors;
        end
        
        function GetRolling(obj)  
            obj.Output=obj.RollingPeriod;        
        end
        
        function GetBetas(obj)
            obj.Output=obj.Betas;        
        end
    end
        
    methods (Static)
        %% Function to create a forward estimation
        % this function creates the estimated Y from the betas array and
        % the matrix of correspondant Regressors
        % INPUTS:
        % Betas = horizontal array 1xK with alfa in the first column and then the
        % K-1 betas
        % RegressorsTimeSeries = array TxK with dates in the first colum
        % and then the time series of any regressor (in the same order of the betas!) 
        % OUTPUTS:
        % output = Tx2 array with the dates in the first colum and the
        % estimated Y in the second
        
        function output=ForecastFromBetas(Betas,RegressorsTimeSeries)
            % check matrix compatibility
            numberOfRegressors = size(RegressorsTimeSeries,2);
            numberOfBetas = size(Betas,2);
            steps = size(RegressorsTimeSeries,1);
            
            if numberOfRegressors ~= numberOfBetas
                E=MException('myComponent:dateError','numero di beta non compatibile col numero di regressori');
                throw(ME)
            end
            
            alfa(1:steps,1)=Betas(1);
            beta=Betas(2:end)';
            dates=RegressorsTimeSeries(:,1);
            X=RegressorsTimeSeries(:,2:end);
            mtxResult=alfa+X*beta;
            output=[dates,mtxResult];
        end
        %% this function Create a logical mtx to choose some regressors using different criteria
        function matrix=getMtxPredictors(obj,numberOfTry,method,varargin)
            
            % ******************************************************
            %
            % THIS IS THE MAXIMUM CORRELATION ALLOWED BETWEEN REGRESSORS
            THRESHOLD = 0.75;
            %
            % ******************************************************
            switch method
                case 'strategy'
                    if nargin<=3
                        ME=MException('myComponent:dateError','manca array con le strategie dei regressori',obj.HFund.Name);
                        throw(ME)
                    end
               
                % in this case the matrix group the index of the same asset
                % class (e.g. all the equity indexes, credit indexes etc)
                assetclass=varargin{1,1};
                step=1;
                mtxstep=1;
                matrix=zeros(1,size(assetclass,2));
                test=assetclass(1,step);
                matrix(mtxstep,:)=strcmp(test,assetclass(1,:));
                step=step+1;
                mtxstep=mtxstep+1;
                while step<=size(assetclass,2)
                    test=assetclass(1,step);
                    if sum(strcmp(test,assetclass(1,1:step-1)))==0
                        matrix(mtxstep,:)=strcmp(test,assetclass(1,:));
                        mtxstep=mtxstep+1;
                    end
                    while step<=size(assetclass,2) & strcmp(test,assetclass(1,step))
                        step=step+1;
                    end
              end
                
                case 'random'
                    % in this case the mtx is random 
                    % any row conmtains a random vector of 1 and 0
                    % no constraints on the numeber of 1s
                    % the matrix has numberOfTry rows
                    matrix=round(rand(numberOfTry,size(obj.TableRet,2)-2));
                
                case 'correlation'        
                    % this finction select a subset of regressors with
                    % correlation < gate (first try gate=0.75) step by step
                    % (any row has a regressor deleted
                    
                    indexcorr=corrcoef(table2array(obj.TableRet(:,2:end-1)));
                    gate=abs(indexcorr)> THRESHOLD;
                    gateswitch=sum(gate,1);
                    [A,I]=sort(gateswitch,'descend');
                    H=ones(size(I,2),size(I,2));
                    counter=0;
                    riga=2;
                    while A(1,1)>1
                        H(riga:end,I(1,1))=0;
                        gate(I(1,1),:)=0;
                        gate(:,I(1,1))=0;
                        gateswitch=sum(gate,1);
                        riga=riga+1;
                        [A,I]=sort(gateswitch,'descend');
                        if counter>size(obj.TableRet,2)*5
                            break
                        end
                    end
                    H(riga:end,:)=[];
                    matrix=H;
                otherwise
                % to be implemented
                    disp('maybe you are using a wrong method name...')
                    disp('at the moment this function accept the following methods:')
                    disp('strategy   random   correlation')
                    disp('            ')
                    disp('press any key to continue')
                    pause
                    matrix=ones(1,size(obj.TableRet,2)-2); %this may be deleted
            end
        end
        
        %% this function create a struct with many quality test for the regression
        function RTest=RegressionTest(LRObject)
            RTest.OrdRSquared=LRObject.Rsquared.Ordinary;
            RTest.AdjRSquared=LRObject.Rsquared.Adjusted;
            RTest.MSE=LRObject.MSE;
            Anova=anova(LRObject,'summary');
            RTest.FTest=table2array(Anova(2,4));
            RTest.PValue=table2array(Anova(2,5));
        end
    end
    
    
end

