classdef HFSimpleConstrReg < HFRegression
    % subclass of HFRegression to perform simple regressions on a selected
    % subset of predictors
    
    
    methods
        % constructor
        function obj = HFSimpleConstrReg(params)
            
            obj = obj@HFRegression(params);
            
        end
    
        function SimpleRegConstr(obj,LogicalMTX)
            
            % this is the logical matrix to select between the regressors
            % any row of the matrix must be composed in this way:
            % 1 = take this regressor 
            % 0 = discard this regressor
            % the number of the column must be the same of the regressors
            obj.MtxOfRegressors = LogicalMTX;
            
            obj.Betas=zeros(size(obj.MtxOfRegressors,1),size(obj.MtxOfRegressors,2)+1);
            testmin=100;
            
            % for any matrix rows it performs the regression and check if
            % it's better of the previous best (using MSE)
            for i=1:size(obj.MtxOfRegressors,1)
                
                % sets the table to perform the regression on
                colmns = [find(obj.MtxOfRegressors(i,:)),size(obj.TableRet,2)];
                selectedTable = obj.TableRet(:,colmns);
                
                % this is the regression 
                temporary = fitlm(selectedTable);
                
                % writes the betas 
                obj.Betas(i,[1,colmns(1:end-1)+1]) = temporary.Coefficients.Estimate';
                
                % creates and fills the regression statistic structure (for
                % any try
                RT=obj.RegressionTest(temporary);
                stats.OrdRS(i)=RT.OrdRSquared;
                stats.AdjRS(i)=RT.AdjRSquared;
                stats.MSE(i)=RT.MSE;
                stats.FTest(i)=RT.FTest;
                stats.PValue(i)=RT.PValue;
                
                % Checks for the goodness of the regresson compared to
                % the previous best regression in terms of MSE
                if stats.MSE(i)<testmin
                   obj.RegResult = temporary;
                   testmin=stats.MSE;
                end
                   
            end
            obj.RegTests=stats;
            k=find(abs(obj.Betas)<1e-9);
            obj.Betas(k)=0;
            dates=zeros(size(obj.Betas,1),1);
            dates(:)=obj.TableRet.date(end);
            obj.Betas=array2table([dates,obj.Betas],'VariableNames',['Dates','Intercept',{obj.TableRet.Properties.VariableNames{2:end-1}}]);
        end
        
        function GetMTXBetas(obj)
            obj.Output=obj.Betas;        
        end
    end
end