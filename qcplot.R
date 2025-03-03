###########################################################################################################
## Proteomics Visualization R Shiny App
##
##This software belongs to Biogen Inc. All right reserved.
##
##@file: qcplot.R
##@Developer : Benbo Gao (benbo.gao@Biogen.com)
##@Date : 5/16/2018
##@version 1.0
###########################################################################################################


observe({
	#DataIn = DataReactive()
	groups = group_order()
	allsamples = all_samples()
	allgroups = all_groups()
	MetaData=all_metadata()
	samples <- sample_order()
	updateSelectizeInput(session,'QC_groups', choices=allgroups, selected=groups)
	updateSelectizeInput(session,'QC_samples', choices=allsamples, selected=samples)
	attributes=setdiff(colnames(MetaData), c("sampleid", "Order", "ComparePairs") )
	updateSelectInput(session, "PCAcolorby", choices=attributes, selected="group")
	updateSelectInput(session, "PCAshapeby", choices=c("none", attributes), selected="none")
	updateSelectInput(session, "PCAsizeby", choices=c("none", attributes), selected="none")
	sampleIDs=setdiff(colnames(MetaData), c("Order", "ComparePairs") )
	updateRadioButtons(session,'PCA_label', inline = TRUE, choices=sampleIDs, selected="sampleid")
	updateTextAreaInput(session, "PCA_list", value=paste(samples, collapse="\n"))
	updateSelectInput(session, "covar_variates", choices=attributes, selected=attributes)
	updateTextInput(session, "Ylab", value=exp_unit())
})
	




output$reorder_group=renderUI({
  req(group_order())
  orderInput(inputId = 'order_groups', label = 'Drag and Drop to Reorder Groups. (Use Select Groups at left menu to delete or add groups.)', items =group_order(), width="90%", item_class = 'primary', legacy =TRUE )
})

output$sample_choose_order=renderUI({
  req(group_order())
  req(sample_order())
  group_exclude<-setdiff(all_groups(), group_order())
  sample_exclude<- setdiff(all_samples(), sample_order())
  #browser() #debug
  tagList(
  tags$div(
    tags$hr(style="border-color: RoyalBlue;"),
    tags$p("Groups excluded: ", paste(group_exclude, collapse=", "), tags$br(), "Samples from these groups will be removed from plotting and analysis.")),
    checkboxInput("remove_samples", "Remove additonal samples?", TRUE, width="90%"),
    conditionalPanel(condition="input.remove_samples==1",
                     textAreaInput("sample_exclude_list", "Enter Samples to Exclude:", "",  width="500px", height="125px"),
                    actionButton("remove_sample", "Remove Samples in the Box Above"),
                    tags$p("Additional samples to be manualy removed:", paste(samples_excludeM(), collapse=", ")) ),
    tags$p("All samples to be excluded: ", paste(sample_exclude, collapse=", ")),
    tags$br(),
    tags$hr(style="border-color: RoyalBlue;"),
    checkboxInput("show_samples", "Show samples chosen for plots and reoder samples?", TRUE, width="90%"),
    conditionalPanel(condition="input.show_samples==1",
    orderInput(inputId = 'order_samples', label = 'Drag and Drop to Reorder Samples.', items =sample_order(), width="90%", item_class = 'success', legacy =TRUE ))
  )
})



observeEvent(input$order_groups_order, {  
  group_order(input$order_groups_order)
})
observeEvent(input$order_samples_order, {  
  sample_order(input$order_samples_order)
})
observeEvent(input$QC_groups, {  
  group_order(input$QC_groups)
})

output$selectGroupSample <- renderText({ paste("Selected ",length(group_order()), " out of ", length(all_groups()), " Groups, ", 
                                               length(sample_order()), " out of ", length(all_samples()), " Samples.", sep="")})


observe({
  req(group_order())
  MetaData=all_metadata()
  groups = group_order()
  allsamples=all_samples()
  MetaData1<-MetaData%>%filter(group %in% groups)
  samples <- as.character( MetaData1$sampleid[order(match(MetaData1$group,groups))])
  sample_R= samples_excludeM() #extra samples to remove
  ToRemove=( toupper(samples) %in% toupper(sample_R) )
  if  (sum(ToRemove)>0) {samples=samples[!ToRemove]}
  sample_order(samples)
})

observeEvent(input$QC_samples, {  
  sample_order(input$QC_samples)
})

observeEvent(input$remove_sample, {  
  sample_list=input$sample_exclude_list
  if(grepl("\n",sample_list)) {
    sample_list <-  stringr::str_split(sample_list, "\n")[[1]]
  } else if(grepl(",",sample_list)) {
    sample_list <-  stringr::str_split(sample_list, ",")[[1]]
  }
  sample_list <- gsub(" ", "", sample_list, fixed = TRUE)
  sample_list <- unique(sample_list[sample_list != ""])
  samples=all_samples()
  ToRemove=( toupper(samples) %in% toupper(sample_list) )
  #browser() #debug
  if  (sum(ToRemove)>0) {
    samples_excludeM(samples[ToRemove])
  }
})



observeEvent(input$reset_group, {
  allgroups = all_groups()
  group_order(allgroups)
  samples_excludeM("")
  samples=all_samples()
  sample_order(samples)
})

DataQCReactive <- reactive({
	DataIn = DataReactive()
	results_long = DataIn$results_long
	ProteinGeneName = DataIn$ProteinGeneName
	MetaData = DataIn$MetaData
	data_long = DataIn$data_long
	data_wide = DataIn$data_wide

	input_groups = input$QC_groups
	#group_order(input$QC_groups)
	input_samples = input$QC_samples
	input_keep = which((MetaData$group %in% input_groups) & (MetaData$sampleid %in% input_samples))
	data_wide  <- data_wide[apply(data_wide, 1, function(x) sum(length(which(x==0 | is.na(x)))) < 3),]
	tmp_data_wide = data_wide[,input_keep] %>% as.matrix()

	
	tmp_data_long = dplyr::filter(data_long, (group %in% input_groups) & (sampleid %in% input_samples))
	tmp_group = MetaData$group[input_keep]
	tmp_sampleid = MetaData$sampleid[input_keep]

	return(list('tmp_data_wide'=tmp_data_wide,'tmp_data_long'=tmp_data_long,'tmp_group' = tmp_group, 'tmp_sampleid'=tmp_sampleid, "MetaData"=MetaData[input_keep, ] ))
})

DataPCAReactive <- reactive({
	DataQC <-  DataQCReactive()
	tmp_sampleid <- DataQC$tmp_sampleid
	tmp_data_wide <- DataQC$tmp_data_wide
	tmp_group = DataQC$tmp_group

	tmp_data_wide[is.na(tmp_data_wide)] <- 0 
	pca <- 	prcomp(t(tmp_data_wide),rank. = 10, scale = FALSE)
	percentVar <- 	round((pca$sdev)^2/sum(pca$sdev^2), 3) * 100
	scores <- as.data.frame(pca$x)
	rownames(scores) <- tmp_sampleid
	scores$group <- factor(tmp_group, levels = group_order())
	attributes=setdiff(colnames(DataQC$MetaData), c("Order", "ComparePairs", "group") )
	MetaData=DataQC$MetaData
	colsel=match(attributes, colnames(MetaData) )
	scores=cbind(scores, MetaData[, colsel, drop=F])
	#browser() #debug
	return(list('scores'=scores,'percentVar'=percentVar))
})

#Eigenvalue bar chart
Eigenvalues_plot<-reactive({
  req(DataPCAReactive())
  PCAlist <- DataPCAReactive()
  scores <- PCAlist$scores
  percentVar <- PCAlist$percentVar
  plotdata<-data.frame(PC=names(scores)[1:10], perVar=percentVar[1:10])
  plotdata$PC=factor(plotdata$PC, levels=plotdata$PC)
  plotdata<-plotdata%>%mutate(TotalVar=cumsum(perVar))
  adj.factor=max(plotdata$TotalVar)/max(plotdata$perVar)*0.9
  p<-ggplot(plotdata, aes(x=PC) )+geom_bar(aes(y=perVar), stat="identity", fill="blue4")+
    geom_line(aes(y=TotalVar/adj.factor), size=1.5, color="red4", group=1)+geom_point(aes(y=TotalVar/adj.factor), size=3, color="red4")+
    labs(x="Principal Components")+scale_y_continuous(name="Percentage of Variance", sec.axis=sec_axis(~.*adj.factor, name="Total Variance") ) +theme_cowplot()
  return(p)
})
output$Eigenvalues <- renderPlot({
  Eigenvalues_plot()
})


########## boxplot
QCboxplot_out <- reactive({
	withProgress(message = 'Making box plot', value = 0, {
		DataQC <-  DataQCReactive()
		tmp_sampleid <- DataQC$tmp_sampleid
		tmp_data_long <- DataQC$tmp_data_long %>% dplyr::filter(expr !=0) %>% sample_n(1000)
			
		tmp_group = DataQC$tmp_group
		#colorpal = get_palette("Dark2", length(tmp_sampleid))
	
		p <- ggplot(tmp_data_long, aes(x=sampleid, y=expr)) +
		geom_boxplot(aes(color=factor(sampleid)), outlier.colour = NA) +

		#scale_fill_manual(values=rep("Dark2", length(tmp_sampleid)))+

		coord_cartesian(ylim = range(boxplot(tmp_data_long$expr, plot=FALSE)$stats)*c(.9, 1.2)) +
		labs(x = "Sample", y = exp_unit()) +
		theme_bw(base_size = 20) +
		theme(legend.position = "bottom",	legend.title=element_blank(),	axis.text.x = element_blank(), plot.margin=unit(c(1,1,1,1),"mm")) +
		guides(col = guide_legend(ncol = 8))
		return(p)
	}
)
})

output$QCboxplot <- renderPlot({
	QCboxplot_out()
})

observeEvent(input$QCboxplot, {
	saved_plots$QCboxplot <- QCboxplot_out()
})


######## PCA
pcaplot_out <- eventReactive (input$plot_PCA, {
  req(DataPCAReactive())
	pcnum=as.numeric(input$pcnum)
	validate(need(length(pcnum)==2, message = "Select 2 Prinical Components."))

	#DataQC <-  DataQCReactive()
	#tmp_group = DataQC$tmp_group
	
	PCAlist <- DataPCAReactive()
	scores <- PCAlist$scores
	percentVar <- PCAlist$percentVar
	samples=scores$sampleid

	xlabel <- paste("PC",pcnum[1],"(",round(percentVar[pcnum[1]]),"%)",sep="")
	ylabel <- paste("PC",pcnum[2],"(",round(percentVar[pcnum[2]]),"%)",sep="")

	PC1 <- paste("PC",pcnum[1],sep="")
	PC2 <- paste("PC",pcnum[2],sep="")

	n <- length(unique(as.character(unlist(scores[, colnames(scores)==input$PCAcolorby]))))
	#colorpal = topo.colors(n, alpha = 1)
	#colorpal = get_palette("Dark2", n)
	colorpal = colorRampPalette(brewer.pal(8, input$PCAcolpalette))(n)
	
	#if (all(table(tmp_group))<4)
	#  ellipsoid = FALSE 

	if (input$PCA_subsample=="None" ) {labels=NULL
	} else {
	  label_sel=match(input$PCA_label, names(scores))
	 # browser() #debug
	  labels=unlist(scores[, label_sel])	
	  if (input$PCA_subsample=="Subset") {
	    PCA_list=str_split(input$PCA_list, "\n")[[1]]
	    N_sel=match(PCA_list, samples)
	    N_sel=N_sel[!is.na(N_sel)]
	    validate(need(length(N_sel)>0, message = "Enter at least one valid sampleid to label"))
	    keep_s=rep(FALSE, length(labels))
	    keep_s[N_sel]=TRUE
	    labels[!keep_s]=""
	    #browser() #debug
	  }
	}

	if (input$PCAshapeby=="none") {shape_by=19} else {shape_by=input$PCAshapeby}
	if (input$PCAsizeby=="none") {size_by=input$PCAdotsize} else {size_by=input$PCAsizeby}	
	
	p <- ggpubr::ggscatter(scores,x =PC1, y=PC2, color =input$PCAcolorby, shape=shape_by, size =size_by , palette= colorpal, ellipse = input$ellipsoid, mean.point = input$mean_point, rug = input$rug,
	                       label =labels, font.label = input$PCAfontsize, repel = TRUE,  ggtheme = theme_bw(base_size = 20) )
	p <- ggpubr::ggpar(p, xlab = xlabel, ylab = ylabel)
	#	browser() #debug	
	#	p <- ggpubr::ggpar(p, legend.title ="", xlab = xlabel, ylab = ylabel, legend = "bottom") #works only when use color by. 
	p <- p + guides(color = guide_legend(override.aes = list(label="")))
	return(p)
})

output$pcaplot <- renderPlot({
	pcaplot_out()
})

observeEvent(input$pcaplot, {
	saved_plots$pcaplot <- pcaplot_out()
}
)

output$pca_legend <- renderPlot({
  PCAlist <- DataPCAReactive()
  scores <- PCAlist$scores
  color_by=input$PCAcolorby
  tmp_group=as.character(unlist(scores[, colnames(scores)==color_by]))
  n <- length(unique(tmp_group))
  colorpal = colorRampPalette(brewer.pal(8, input$PCAcolpalette))(n)
  tmp_plot<-ggplot(scores, aes_string(x="PC1", y="PC2", color=color_by))+geom_point()+scale_color_manual(values=colorpal)+ theme_cowplot(12)
  legend_only <- get_legend(tmp_plot +theme(legend.position = "bottom",  legend.title = element_text(size = 16),
                                            legend.text = element_text(size = 14))+guides(color = guide_legend(override.aes = list(size=8))))
  plot_grid(legend_only)
})

######## PCA 3D
output$plot3d <- renderRglwidget({
 	PCAlist <- DataPCAReactive()
	scores <- PCAlist$scores
	percentVar <- PCAlist$percentVar

	xlabel <- paste("PC1(",round(percentVar[1]),"%)",sep="")
	ylabel <- paste("PC2(",round(percentVar[2]),"%)",sep="")
	zlabel <- paste("PC3(",round(percentVar[3]),"%)",sep="")

	sampleid <- rownames(scores)
	
	tmp_group=as.character(unlist(scores[, colnames(scores)==input$PCAcolorby]))
	n <- length(unique(tmp_group))
	#colorpal = topo.colors(n, alpha = 1)
	#colorpal = get_palette("Dark2", n)
	colorpal = colorRampPalette(brewer.pal(8, input$PCAcolpalette))(n)
	scores$tmp_group=as.factor(tmp_group)

	
	#rgl.open(useNULL=T)
	options(rgl.useNULL=TRUE)
	if (input$ellipsoid3d == "Yes") {
	  ellipsoid3d = TRUE
	} else {
	  ellipsoid3d = FALSE 
	}


	if (any(table(tmp_group) <= 3))
	  ellipsoid3d = FALSE 
	

	
	if (input$dotlabel == "Yes") {
	  dotlabel=TRUE
	} else {
	  dotlabel=FALSE
	}

	scatter3d(PC3 ~ PC1 + PC2 | tmp_group, data= scores,
	          axis.col= c("black", "black", "black"),
	          xlab=xlabel, ylab=ylabel,  zlab=zlabel, labels = as.factor(sampleid), id=dotlabel, id.n=length(sampleid),
	          axis.scales=FALSE,  axis.ticks=FALSE,
	          ellipsoid = ellipsoid3d,
	          surface=FALSE, grid = FALSE,
	          cex.lab=3,
	          surface.col = colorpal)
	rglwidget(width = 800, height = 800)
})

output$plotly3d <- renderPlotly({
	PCAlist <- DataPCAReactive()
	scores <- PCAlist$scores
	scores<-scores%>%mutate_if(is_character, as.factor)
	percentVar <- PCAlist$percentVar
	symbol_list=rep(c('circle', 'square',  'diamond',  'circle-open','square-open','diamond-open'), 2) #symbols which work with plotly scatter3d
	plot_symbols=symbol_list[unique(as.numeric(unlist(scores[, colnames(scores)==input$PCAshapeby])))]
	
	xlabel <- paste("PC1(",round(percentVar[1]),"%)",sep="")
	ylabel <- paste("PC2(",round(percentVar[2]),"%)",sep="")
	zlabel <- paste("PC3(",round(percentVar[3]),"%)",sep="")

	sampleid <- str_c(scores$sampleid, "\n", scores$group)
	n <- length(unique(as.character(unlist(scores[, colnames(scores)==input$PCAcolorby]))))
	colorpal = colorRampPalette(brewer.pal(8, input$PCAcolpalette))(n)
	if (input$PCAshapeby=="none"){
	  p <- plot_ly(scores, x = ~PC1, y = ~PC2, z = ~PC3, color = as.formula(paste0("~", input$PCAcolorby)), 
	               colors = colorpal,text = sampleid) %>%
	    add_markers() %>%
	    layout(scene = list(xaxis = list(title = xlabel), yaxis = list(title = ylabel),  zaxis = list(title = zlabel)))
	  
	} else{
	p <- plot_ly(scores, x = ~PC1, y = ~PC2, z = ~PC3, color = as.formula(paste0("~", input$PCAcolorby)), 
	              symbol=as.formula(paste0("~", input$PCAshapeby)),symbols=plot_symbols, 
	             colors = colorpal,text = sampleid) %>%
	add_markers() %>%
	layout(scene = list(xaxis = list(title = xlabel), yaxis = list(title = ylabel),  zaxis = list(title = zlabel)))
	}
	p$elementId <- NULL
	p
})

############heatmap
pheatmap_out <- reactive({
	DataQC <-  DataQCReactive()
	tmp_sampleid <- DataQC$tmp_sampleid
	tmp_data_wide <- DataQC$tmp_data_wide
	tmp_group = DataQC$tmp_group
	MetaData=DataQC$MetaData
	
	selCol=which(names(MetaData)==input$PCAcolorby)
	annotation=MetaData[, selCol, drop=F]
	#annotation = data.frame("group" = tmp_group)
	rownames(annotation) <- tmp_sampleid

	sampleDistMatrix <- as.matrix(dist(t(tmp_data_wide)))
	rownames(sampleDistMatrix) <- tmp_sampleid
	colors <- colorRampPalette(rev(brewer.pal(9, "Blues")) )(32)

	p <- pheatmap::pheatmap(sampleDistMatrix, annotation_row=annotation,	annotation_col=annotation, col=colors)
	return(p)
})

output$pheatmap <- renderPlot({
	grid.draw(pheatmap_out()$gtable)
})

observeEvent(input$SampleDistance, {
	saved_plots$SampleDistance <- pheatmap_out()$gtable
}
)

############Dendrograms
Dendrograms_out <- reactive({
	hc <- pheatmap_out()$tree_row
	if (input$dendroformat=="tree") {
		p <- fviz_dend(hc, k = input$DendroCut, cex = input$DendroFont, k_colors = "jco",	color_labels_by_k = TRUE, rect = TRUE, rect_border = "jco",	rect_fill = TRUE)
	} else 	if (input$dendroformat=="horiz") {
		p <- fviz_dend(hc, k = input$DendroCut, cex = input$DendroFont, k_colors = "jco",	 horiz = TRUE, color_labels_by_k = TRUE, rect = TRUE, rect_border = "jco", rect_fill = TRUE)
	} else if (input$dendroformat=="circular") {
		p <- fviz_dend(hc, k = input$DendroCut, cex = input$DendroFont, k_colors = "jco", type = "circular")
	}
	return(p)
})

output$Dendrograms <- renderPlot({
	Dendrograms_out()
})

observeEvent(input$Dendrograms, {
	saved_plots$Dendrograms <- Dendrograms_out()
})

############histplot
histplot_out <- reactive({
  withProgress(message = 'Calculating.',  detail = 'This may take a while...', value = 0, {
	DataQC <-  DataQCReactive()
	tmp_sampleid <- DataQC$tmp_sampleid
	tmp_data_long <- DataQC$tmp_data_long
	tmp_group = DataQC$tmp_group
  #browser() #debug
	CV.df <- tmp_data_long %>%
	group_by(.,  group, id) %>%
	dplyr::summarise( mean=mean(expr, na.rm = TRUE), sd=sd(expr, na.rm = TRUE)) %>%
	dplyr::mutate(CV=100*(sd/mean))

	mu <- group_by(CV.df,group) %>%
	dplyr::summarise(median = round(median(CV, na.rm = TRUE),1))

	interval <- seq.int(0, 100, 5)
	xlimmin <- interval[cut(min(mu$median), interval, include.lowest = TRUE, labels = FALSE)]
	xlimmax <- interval[cut(max(mu$median), interval, include.lowest = TRUE, labels = FALSE) +1]
	p <- ggplot(CV.df, aes(x=CV, color=group)) +
	geom_freqpoly (position="dodge", na.rm = TRUE, bins = 10) +
	geom_vline(data=mu, aes(xintercept=median, color=group), linetype="dashed") +
	geom_text(data=mu, mapping=aes(x=median, y=0, label=paste(median,"(",group,")", sep="")), size=4, angle=90, vjust=-0.4, hjust=0) +
	scale_x_continuous(breaks = seq(xlimmin, xlimmax, by=5), limits=c(xlimmin,xlimmax)) +
	theme_bw(base_size = 20) +
	theme(legend.position = "bottom")
	return(p)
  })
})

output$histplot <- renderPlot({
	histplot_out()
})

observeEvent(input$histplot, {
	saved_plots$histplot <- histplot_out()
})


############PC_covariates QC Plots
PC_covariates_out <-  eventReactive(input$compute_PC,{
  DataQC <-  DataQCReactive()
  tmp_data_wide <- DataQC$tmp_data_wide
  MetaData=DataQC$MetaData
  meta=MetaData[, !(colnames(MetaData) %in% c("sampleid", "Order", "ComparePairs")), drop=FALSE]
  meta=meta[, (colnames(meta) %in% input$covar_variates), drop=FALSE]
  rownames(meta)=MetaData$sampleid
  res<-Covariate_PC_Analysis(tmp_data_wide, meta, out_prefix=NULL, PC_cutoff=input$covar_PC_cutoff, 
            FDR_cutoff=input$covar_FDR_cutoff, N_col=input$covar_ncol)
  return(res)
})

#output$covar_table=renderTable(PC_covariates_out()$selVar_All, colnames=T)

output$covar_table <- DT::renderDataTable({
  results<-PC_covariates_out()$selVar_All
  if (!is.null(results)) {
    results["P-value"]=as.numeric(formatC(unlist(results["P-value"]), format="e", digits=2))
    results["FDR"]=as.numeric(formatC(unlist(results["FDR"]), format="e", digits=2))
  }
  DT::datatable(results,  extensions = 'Buttons',
                options = list(
                  dom = 'lBfrtip', buttons = c('csv', 'excel', 'print'),
                  pageLength = 25
                ),rownames= T)
})


output$PC_covariatesC <- renderPlot({
  data=PC_covariates_out()$sel_dataC
  if (!is.null(data)) {
    data$plot
  }
})
output$plot.PC_covariatesC=renderUI({
  tagList(
    textOutput("N_pairs_C"),
    plotOutput("PC_covariatesC",height = input$covar_cat_height)
  )
}) 


output$PC_covariatesN <- renderPlot({
  data=PC_covariates_out()$sel_dataN
  if (!is.null(data)) {
    data$plot
  }
})
output$plot.PC_covariatesN=renderUI({
  tagList(
  textOutput("N_pairs_N"),
  plotOutput("PC_covariatesN",height = input$covar_num_height)
  )
})

Npairs_cov<-reactive({
  res<-PC_covariates_out()
  C=res$sel_dataC$selVar
  if (is.null(C)) {N1=0} else {N1=nrow(C)}
  N=res$sel_dataN$selVar
  if (is.null(N)) {N2=0} else {N2=nrow(N)}
  return(c(N1, N2))
})

observe({
  H_C=ceiling(Npairs_cov()[1]/PC_covariates_out()$ncol)*400
  if (H_C>0)  { updateSliderInput(session, "covar_cat_height", value = H_C)}
  H_N=ceiling(Npairs_cov()[2]/PC_covariates_out()$ncol)*400
  if (H_N>0)  { updateSliderInput(session, "covar_num_height", value = H_N)}  
})

output$N_pairs_C<-renderText({str_c("There are ", Npairs_cov()[1], " significant categorical covariate-PC pairs.")})
output$N_pairs_N<-renderText({str_c("There are ", Npairs_cov()[2], " significant numeric covariate-PC pairs.")})
output$N_pairs<-renderText({str_c("There are ", Npairs_cov()[1]+Npairs_cov()[2], " significant covariate-PC pairs.")})


observeEvent(input$covar_cat, {
  data=PC_covariates_out()$sel_dataC
  saved_plots$covar_cat <- data$plot
})

observeEvent(input$covar_num, {
  data=PC_covariates_out()$sel_dataN
  saved_plots$covar_num<- data$plot
})
