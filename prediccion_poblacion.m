% Cálculos de predicción de pirámides poblacionales
% 2017 - Jose Luis Blanco Claraco
% Blog: Ciencia-Explicada.com
% Código liberado al dominio público.
% ------------------------------------------------------

% Nota: 
% La prediccion de población a 2030/31 concuerda perfectamente con 
% la proyección del INE, lo que da confianza en los cálculos:
% http://www.ine.es/dyngs/INEbase/es/operacion.htm?c=Estadistica_C&cid=1254736176953&menu=ultiDatos&idp=1254735572981

function [] = prediccion_poblacion()
close all;

NUM_AGNOS_A_SIMULAR = 20;

t_mort   = csvread('INE2013_tasa_mortalidad.csv');
pob_edad_org = csvread('INE2016_poblacion_por_edad.csv');

% Dividir piramide en franjas de 1 año en lugar de 5:
n_edades = size(pob_edad_org,1);
pob_edad = zeros(n_edades,2);
for i=1:n_edades,
    pob_edad( (i-1)*5+(1:5), 1 ) = (i-1)*5+(1:5);
    pob_edad( (i-1)*5+(1:5), 2 ) = ones(5,1) .* pob_edad_org(i,2) / 5;
end

tasa_natalidad = 9 / 1000.0; % EUROSTAT 2015. Nacimientos / 1000

% Datos del CIS FEB-2017: http://www.cis.es/cis/export/sites/default/-Archivos/Marginales/3160_3179/3168/cru3168edad.html
franja_edades{1} = struct('min',18,'max',24,'abs',100-62.2,'pp',12.3,'psoe',18.9,'podemos',26.2+4.9+0.8,'cs',11.5);
franja_edades{2} = struct('min',25,'max',34,'abs',100-75.4,'pp',13.2,'psoe',14.0,'podemos',20.2+1.9+3.5,'cs',19.0);
franja_edades{3} = struct('min',35,'max',44,'abs',100-81.7,'pp',15.6,'psoe',17.6,'podemos',18.3+2.7+3.7,'cs',14.6);
franja_edades{4} = struct('min',45,'max',54,'abs',100-85.7,'pp',18.5,'psoe',21.7,'podemos',12.7+1.7+2.7,'cs',9.2);
franja_edades{5} = struct('min',55,'max',64,'abs',100-88.2,'pp',18.1,'psoe',23.7,'podemos',14.8+1.5+2.7,'cs',4.7);
franja_edades{6} = struct('min',65,'max',200,'abs',100-88.4,'pp',28.6,'psoe',24.2,'podemos',4.7+0.9+0.8,'cs',3.6);

% Empieza simulacion:
figure(1);
set(gcf,'Color',[1 1 1]);
set(gcf,'Position',[0 0 1600 900]);
subplot(2,2,[1 3]);
grid minor;

VOT=[];

for iter = 0:NUM_AGNOS_A_SIMULAR,
    subplot(2,2,[1 3]);
    plot_piramide(pob_edad(:,1),pob_edad(:,2),sprintf('Año %u',2016+iter));
    pob_edad(:,2) = pob_vegetativo( pob_edad(:,2), tasa_natalidad,t_mort);

    pred_voto=predicc_voto(pob_edad(:,1),pob_edad(:,2),franja_edades, iter);

    VOT(iter+1,1)=2016+iter;
    VOT(iter+1,2)=pred_voto.abs / pred_voto.nvoters * 100;
    VOT(iter+1,3)=pred_voto.pp / pred_voto.nvoters * 100;
    VOT(iter+1,4)=pred_voto.psoe / pred_voto.nvoters * 100;
    VOT(iter+1,5)=pred_voto.podemos / pred_voto.nvoters * 100;
    VOT(iter+1,6)=pred_voto.cs / pred_voto.nvoters * 100;
    VOT(iter+1,7)=(pred_voto.nvoters - (pred_voto.abs+pred_voto.pp+pred_voto.psoe+pred_voto.cs+pred_voto.podemos))/ pred_voto.nvoters * 100;
    VOT(iter+1,8)=pred_voto.nvoters;
    
    subplot(2,2,2);
    f=plot(VOT(:,1),VOT(:,2:7),'.');
    set(f,'LineStyle','-');
    legend('Abstención (%)','PP (%)','PSOE (%)', 'UP (%)','Cs (%)','Otros (%)');
    
    subplot(2,2,4);
    f=plot(VOT(:,1),VOT(:,8)*1e-6,'.');
    set(f,'LineStyle','-');
    legend('Población en edad de votar (Millones)');

    pause(0.2);
end

for i=0:4:NUM_AGNOS_A_SIMULAR
    subplot(2,2,2);
    hold on;
    yl=ylim();
    plot(2016+[i i],yl,'k--');

    subplot(2,2,4);
    hold on;
    yl=ylim();
    plot(2016+[i i],yl,'k--');
end



end

function []=plot_piramide(edades,pobs, titulo)

cla;
b1=barh(edades,pobs*1e-3); hold on;
b2=barh(edades,-pobs*1e-3);

set(b1,'LineStyle','none');
set(b2,'LineStyle','none');

title(sprintf('%s (Población total: %.02f M)',titulo,sum(pobs)*1e-6));
ylim([0,105]);
xlim([-1000, 1000]);
xlabel('Miles');
ylabel('Edad');

end

function [out_pobs]=pob_vegetativo(in_pobs,t_nat, t_mort)

ne = length(in_pobs); % Numero de franjas de edades

% Nacimientos:
N=sum(in_pobs);
num_nac = t_nat * N;  % Creia que deberia ser N/1000 pero no... es N

% Transferencia N->N+1 
out_pobs(ne) = in_pobs(ne)+in_pobs(ne-1);
out_pobs(2:(ne-1)) = in_pobs(1:(ne-2));
out_pobs(1) = num_nac;

% Defunciones por tasa de defuncion segun edad:
for i=1:ne,
    if (i<size(t_mort,1))
        tm = t_mort(i,2);
    else
        tm = t_mort(end,2);  % Usar mortalidad para la edad más avanzada registrada
    end
    out_pobs(i) = out_pobs(i) * (1- 1e-3* tm);
end

end

function [pred_voto]=predicc_voto(edades,pobs,franja_edades,num_agnos_pasados)

pred_voto = struct('nvoters',0,'abs',0,'pp',0,'psoe',0,'podemos',0,'cs',0);
ne = length(pobs); % Numero de franjas de edades
N=sum(pobs);

for i=1:ne
    edad = edades(i);
    if (edad<18)
        continue;  % Edad de votar!
    end
    N_edad = pobs(i);
    
    % Encontrar franja edad correspondiente (este algoritmo de búsqueda es muy
    % ineficiente, pero voy programando con prisa así que me da igual ;-)
    myj = 0;
    edad_correg = edad-num_agnos_pasados;
    if (edad_correg<18)  % Para los nuevos votantes, asumir que "continuan" con las ideas de los jovenes de ahora
        edad_correg = 18;
    end
    for j=1:length(franja_edades)
        if (edad_correg>=franja_edades{j}.min && edad_correg<=franja_edades{j}.max)
            myj = j;
            break;
        end            
    end
    if (myj<1)
        assert(myj>0);
    end
    
    fe = franja_edades{myj};
    pred_voto.abs = pred_voto.abs + N_edad * fe.abs*0.01;
    
    pred_voto.nvoters = pred_voto.nvoters + N_edad;
    Nvoters = N_edad * (1 - fe.abs*0.01);
    pred_voto.pp = pred_voto.pp + Nvoters * fe.pp*0.01;
    pred_voto.psoe = pred_voto.psoe + Nvoters * fe.psoe*0.01;
    pred_voto.cs = pred_voto.cs + Nvoters * fe.cs*0.01;
    pred_voto.podemos = pred_voto.podemos + Nvoters * fe.podemos*0.01;
end

end
