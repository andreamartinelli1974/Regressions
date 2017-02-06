classdef Regression < handle
    %% Class to perform regression on a single timeseries using many regressors
    
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
        Input; %input struct
        TableRet; %input table for fitlm(table) regressors + dependent variable in last column
        MtxOfRegressors = []; %the logical matrix that specify wich regressors are effectively used in the regression
        RegResult; % the result of the regression. It's a LinearModel object
        RegTests; %TO BE WELL DEFINED include the result of different test of the regression quality
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
        
        %% this function Create a logical mtx to choose some regressors using different criteria
        function matrix=getMtxPredictors(obj,numberOfTry,method)
            
            % ******************************************************
            %
            % THIS IS THE MAXIMUM CORRELATION ALLOWED BETWEEN REGRESSORS
            THRESHOLD = 0.75;
            %
            % ******************************************************
            
            if strcmp(method,'strategy')
% % % TO IMPLEMENT THIS PART OF THE METHOD WITHOUT THE INDEX CLASS                
% %                 % in this case the matrix group the index of the same asset
% %                 % class (e.g. all the equity indexes, credit indexes etc)
% %                 assetclass=cell(2,size(obj.Regressors,2));
% %                 for i = 1:size(obj.Regressors,2)
% %                     obj.Regressors(i).GetName;
% %                     assetclass(1,i) = cellstr(obj.Regressors(i).Output);
% %                     obj.Regressors(i).GetAssetClass;
% %                     assetclass(2,i) = cellstr(obj.Regressors(i).Output);
% %                 end
% %                 step=1;
% %                 mtxstep=1;
% %                 matrix=zeros(1,size(obj.Regressors,2));
% %                 test=assetclass(2,step);
% %                 matrix(mtxstep,:)=strcmp(test,assetclass(2,:));
% %                 step=step+1;
% %                 mtxstep=mtxstep+1;
% %                 while step<=size(obj.Regressors,2)
% %                     test=assetclass(2,step);
% %                     if sum(strcmp(test,assetclass(2,1:step-1)))==0
% %                         matrix(mtxstep,:)=strcmp(test,assetclass(2,:));
% %                         mtxstep=mtxstep+1;
% %                     end
% %                     while step<=size(obj.Regressors,2) & strcmp(test,assetclass(2,step))
% %                         step=step+1;
% %                     end
% %               end
                
            elseif strcmp(method,'random')
                % in this case the mtx is random 
                % any row conmtains a random vector of 1 and 0
                % no constraints on the numeber of 1s
                % the matrix has numberOfTry rows
                matrix=round(rand(numberOfTry,size(obj.TableRet,2)-2));
                
            elseif strcmp(method,'correlation')        
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
            else
                % to be implemented
                
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

