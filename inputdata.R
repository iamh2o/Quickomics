###########################################################################################################
## Proteomics Visualization R Shiny App
##
##This software belongs to Biogen Inc. All right reserved.
##
##@file: input.R
##@Developer : Benbo Gao (benbo.gao@Biogen.com)
##@Date : 5/31/2019
##@version 1.0
###########################################################################################################
saved_plots <- reactiveValues()  
saved_table <- reactiveValues() 
group_order <- reactiveVal()
sample_order <- reactiveVal()
all_samples <-reactiveVal()
samples_excludeM<-reactiveVal()
all_groups <-reactiveVal()
all_tests<-reactiveVal()
all_metadata<-reactiveVal()
upload_message <- reactiveVal()
ProteinGeneNameHeader<- reactiveVal()
exp_unit<-reactiveVal()
#saved_palette <- reactiveVal()
ProjectInfo<-reactiveValues(ProjectID=NULL, Name=NULL, Species=NULL, ShortName=NULL, file1=NULL, file2=NULL)
showAlert<-reactiveVal()

observeEvent(input$exp_unit, {
  Eu=input$exp_unit; exp_unit(Eu)
  })

observe({
query <- parseQueryString(session$clientData$url_search)
if (!is.null(query[['project']])) {
  ProjectID = query[['project']]
  validate(need(ProjectID %in% saved_projects$ProjectID , message = "Please pass a valid ProjectID from URL."))
  ProjectInfo$ProjectID=ProjectID
  ProjectInfo$Name=saved_projects$Name[saved_projects$ProjectID==ProjectID]
  ProjectInfo$Species=saved_projects$Species[saved_projects$ProjectID==ProjectID]
  ProjectInfo$ShortName=saved_projects$ShortNames[saved_projects$ProjectID==ProjectID]
  ProjectInfo$file1= paste("data/",  ProjectID, ".RData", sep = "")  #data file
  ProjectInfo$file2= paste("networkdata/", ProjectID, ".RData", sep = "") #Correlation results
}
if (!is.null(query[['unlisted']])) {
  ProjectID = query[['unlisted']]
  unlisted_project=read.csv(str_c("unlisted/", ProjectID, ".csv"))
  ProjectInfo$ProjectID=ProjectID
  ProjectInfo$Name=unlisted_project$Name
  ProjectInfo$Species=unlisted_project$Species
  ProjectInfo$ShortName=unlisted_project$ShortName
  ProjectInfo$file1= paste("unlisted/",  ProjectID, ".RData", sep = "")  #data file
  ProjectInfo$file2= paste("unlisted/", ProjectID, "_network.RData", sep = "") #Correlation results
  if ("ExpressionUnit" %in% names(unlisted_project)) {updateTextInput(session, "exp_unit", value=unlisted_project$ExpressionUnit[1]) }
}
if (!is.null(query[['serverfile']])) {
  ProjectID = query[['serverfile']]
  if (!is.null(server_dir)) {
    unlisted_project=read.csv(str_c(server_dir, "/",  ProjectID, ".csv"))
    ProjectInfo$ProjectID=ProjectID
    ProjectInfo$Name=unlisted_project$Name
    ProjectInfo$Species=unlisted_project$Species
    ProjectInfo$ShortName=unlisted_project$ShortName
    ProjectInfo$file1= paste(server_dir, "/",   ProjectID, ".RData", sep = "")  #data file
    ProjectInfo$file2= paste(server_dir, "/",  ProjectID, "_network.RData", sep = "") #Correlation results
    if ("ExpressionUnit" %in% names(unlisted_project)) {updateTextInput(session, "exp_unit", value=unlisted_project$ExpressionUnit[1]) }
  }
}
})

observe({
if (input$sel_project!="") {
  ProjectID=input$sel_project
  ProjectInfo$ProjectID=ProjectID
  ProjectInfo$Name=saved_projects$Name[saved_projects$ProjectID==ProjectID]
  ProjectInfo$Species=saved_projects$Species[saved_projects$ProjectID==ProjectID]
  ProjectInfo$ShortName=saved_projects$ShortNames[saved_projects$ProjectID==ProjectID]
  ProjectInfo$file1= paste("data/",  ProjectID, ".RData", sep = "")  #data file
  ProjectInfo$file2= paste("networkdata/", ProjectID, ".RData", sep = "") #Correlation results
}
})

observeEvent(ProjectInfo$ProjectID, {
  #cat("load file UI for", ProjectInfo$ProjectID, "\n")
  updateRadioButtons(session, "heatmap_subset",  selected="All")
  output$gene_highlight_file=renderUI({
    tagList(fileInput("file_gene_highlight", "Highlight Genes (csv with headers like Genes, Pathways, Color)"))
  })
  updateRadioButtons(session, "heatmap_highlight",  selected="No")
  output$gene_annot_file=renderUI({
    tagList(fileInput("file_gene_annot", "Choose gene annotation file (csv with headers like Genes, Pathways, Color)"))
  })
  updateRadioButtons(session, "custom_color",  selected="No")
  output$annot_color_file=renderUI({
    tagList(fileInput("annot_color_file", "Upload annotation Colors (csv with 3 headers: Attribute, Value and Color)"))
  })
})

output$project <- renderText({
  if (is.null(ProjectInfo$Name)){"Please select or upload a date set"} else {ProjectInfo$Name}
})

html_geneset<-reactive({
  req(ProjectInfo)
  Species=ProjectInfo$Species
  string=str_replace(html_geneset0, "human", Species)
 #cat(string, "\n") #debug
  return(string)
})
output$html_geneset=renderUI({
  HTML(html_geneset())
})

html_geneset_hm<-reactive({
  req(ProjectInfo)
  Species=ProjectInfo$Species
  string=str_replace(html_geneset_hm0, "human", Species)
  #cat(string, "\n") #debug
  return(string)
})
output$html_geneset_hm=renderUI({
  HTML(html_geneset_hm())
})

html_geneset_exp<-reactive({
  req(ProjectInfo)
  Species=ProjectInfo$Species
  string=str_replace(html_geneset_exp0, "human", Species)
  return(string)
})
output$html_geneset_exp=renderUI({
  HTML(html_geneset_exp())
})


output$ui.action <- renderUI({
  if (is.null(input$file1) ) return()
  tagList(
  textInput("project_name", label="Rename Project", value=input$file1$name),
  radioButtons("species",label="Select species", choices=c("human","mouse", "rat"), inline = F, selected="human"),
  actionButton("customData", "Submit Data")
  )
})


observeEvent(input$customData, {  
  ProjectInfo$ProjectID=str_replace(input$file1$name,  regex(".RData", ignore_case = TRUE), "")
  ProjectInfo$Name=input$project_name
  ProjectInfo$Species=input$species
  ProjectInfo$ShortName=input$project_name
  ProjectInfo$file1=input$file1$datapath; ProjectInfo$file2=input$file2$datapath
  #browser() #debug
})


DataReactive <- reactive({
  req(ProjectInfo$ProjectID)
  withProgress(message = 'Fetching data.',
               detail = 'This may take a while...',
               value = 0,
               {
 
               RDataFile <- ProjectInfo$file1
 
               comp_info=NULL  
               load(RDataFile)
               if (!"Protein.ID" %in% names(ProteinGeneName)) {ProteinGeneName$Protein.ID=NA} #Add Protein.ID column as it is required for certain tools.
                 #if (!exists("comp_info")) {comp_info=NULL}
                 results_long <-
                   results_long %>% mutate_if(is.factor, as.character)  %>% left_join(ProteinGeneName, ., by = "UniqueID")
                 data_long <-
                   data_long %>% mutate_if(is.factor, as.character)  %>% left_join(ProteinGeneName, ., by = "UniqueID")
                 
                 group_names <- as.character(unique((MetaData$Order[MetaData$Order != "" & !is.na(MetaData$Order)])))
                 if (length(group_names) == 0) {
                   group_names <- as.character(unique(MetaData$group))
                 }
                 tests  <-
                   as.character(MetaData$ComparePairs[MetaData$ComparePairs != ""])
		             comp_tests=as.character(unique(results_long$test))
		             if (!all(tests %in% comp_tests) ) { tests <-  gsub("-", "vs", tests) } #for projects where - used in MetaData, "vs" used in results_long
                 if (length(tests) == 0) {
                   tests = unique(as.character(results_long$test))
                 }
		             samples <- as.character( MetaData$sampleid[order(match(MetaData$group,group_names))])
                 group_order(group_names)
                 sample_order(samples)
                 all_samples(samples)
                 all_groups(group_names)
                 all_metadata(MetaData)
                 all_tests(tests)
                 samples_excludeM("")
                 ProteinGeneNameHeader(colnames(ProteinGeneName))
                 return(
                   list(
                     "groups" = group_names,
                     "MetaData" = MetaData,
                     "results_long" = results_long,
                     "data_long" = data_long,
                     "ProteinGeneName" = ProteinGeneName,
                     "data_wide" = data_wide,
                     "data_results" = data_results,
                     "tests" = tests,
                     "comp_info"=comp_info
                   )
                 )
               })
  
})

project_summary<-reactive({
  req(DataReactive())
  DataIn = DataReactive()
  groups=DataIn$groups
  tests=DataIn$tests
  summary=str_c('<style type="text/css">
.disc {
 list-style-type: disc;
}
.square {
 list-style-type: square;
 margin-left: -2em;
 font-size: small
}
</style>',
"<h2>Project ", ProjectInfo$ShortName, "</h2><br>",
    '<ul class="disc"><li>Species: ', ProjectInfo$Species, "</li>",
"<li>Description: ", ProjectInfo$Name, "</li>",
    "<li>Number of Samples: ", nrow(DataIn$MetaData), "</li>",
    "<li>Number of Groups: ", length(groups), " (please see group table below)</li>",  
"<li>Number of Genes/Proteins: ", nrow(DataIn$data_wide), "</li>",
"<li>Number of Comparison Tests: ", length(tests), "</li>",
'<ul class="square">', paste(str_c("<li>", tests, "</li>"), collapse=""), "</ul></li></ul><br><hr>",
"<h4>Number of Samples in Each Group</h4>")
})
output$summary=renderText(project_summary())

group_info<-reactive({
  DataIn <- DataReactive()
  group_info<-DataIn$MetaData%>%group_by(group)%>%dplyr::count()
  #browser() #bebug
  return(t(group_info))
})
output$group_table=renderTable(group_info(), colnames=F)



DataNetworkReactive <- reactive({
  DataIn = DataReactive()
  ProteinGeneName <- DataIn$ProteinGeneName
  #query <- parseQueryString(session$clientData$url_search)
  Pinfo=ProjectInfo
  run_network=FALSE
  CorResFile <- ProjectInfo$file2
  if (is.null(CorResFile))  {
    run_network=TRUE
  } else if (file.exists(CorResFile)) {
    load(CorResFile)
  } else { run_network=TRUE}
  
  if (run_network) {
    withProgress(message = 'Compute correlation network data.',
                 detail = 'This may take a few minutes...',
                 value = 0,
                 {
    data_wide <- DataIn$data_wide
    #if data_wide has many genes, trim down to 10K
    if (nrow(data_wide)>10000 ) {
      dataSD=apply(data_wide, 1, function(x) sd(x,na.rm=T))
      dataM=rowMeans(data_wide)
      diff=dataSD/(dataM+median(dataM))
      data_wide=data_wide[order(diff, decreasing=TRUE)[1:10000], ]	 
      cat("reduce gene size to 10K for project ", ProjectID, "\n")
    }
    cor_res <- Hmisc::rcorr(as.matrix(t(data_wide)))
    cormat <- cor_res$r
    pmat <- cor_res$P
    ut <- upper.tri(cormat)
    network <- tibble (
      from = rownames(cormat)[row(cormat)[ut]],
      to = rownames(cormat)[col(cormat)[ut]],
      cor  = signif(cormat[ut], 2),
      p = signif(pmat[ut], 2),
      direction = as.integer(sign(cormat[ut]))
    )
    network <- network %>% mutate_if(is.factor, as.character) %>%
      dplyr::filter(!is.na(cor) & abs(cor) > 0.7 & p < 0.05)
    if (nrow(network)>2e6) {
      network <- network %>% mutate_if(is.factor, as.character) %>%
        dplyr::filter(!is.na(cor) & abs(cor) > 0.8 & p < 0.005)
    }
    if (nrow(network)>2e6) {
      network <- network %>% mutate_if(is.factor, as.character) %>%
        dplyr::filter(!is.na(cor) & abs(cor) > 0.85 & p < 0.005)
    }
    save(network,
         file =  paste("networkdata/", Pinfo$ProjectID, ".RData", sep = ""))
    ProjectInfo$file2=paste("networkdata/", Pinfo$ProjectID, ".RData", sep = "")
    })
  }
  
  sel_gene = input$sel_net_gene
  tmpids = ProteinGeneName[unique(na.omit(c(
    apply(ProteinGeneName, 2, function(k)
      match(sel_gene, k))
  ))), ]
  
  edges.sel <-
    network %>% filter((from %in% tmpids$UniqueID) |
                         (to %in% tmpids$UniqueID))
  rcutoff <- as.numeric(input$network_rcut)
  pvalcutoff <- as.numeric(as.character(input$network_pcut))
  edges <-
    dplyr::filter(edges.sel, abs(cor) > rcutoff & p < pvalcutoff)
  networks_ids <-
    unique(c(as.character(edges$from), as.character(edges$to)))
  nodes <-
    ProteinGeneName %>% dplyr::filter(UniqueID %in% networks_ids) %>%
    dplyr::select(UniqueID, Gene.Name) %>%
    dplyr::rename(id = UniqueID, label = Gene.Name)
  net <- list("nodes" = nodes, "edges" = edges)
  return(net)
})

output$results <- DT::renderDataTable({
	DataIn <- DataReactive()
	results <- DataIn$data_results %>%
	dplyr::select(-one_of(c("Fasta.headers","UniqueID","id")))
	results[,sapply(results,is.numeric)] <- signif(results[,sapply(results,is.numeric)],3)
	DT::datatable(results,  extensions = 'Buttons',
  options = list(
    dom = 'lBfrtip', buttons = c('csv', 'excel', 'print'),
  	pageLength = 15
  ),rownames= T)
})

output$sample <- DT::renderDataTable({
  meta<-DataReactive()$MetaData%>%dplyr::select(-Order, -ComparePairs)
	DT::datatable(meta,  extensions = 'Buttons',  options = list(
	  dom = 'lBfrtip', buttons = c('csv', 'excel', 'print'), pageLength = 15))
	
})

output$comparison <- DT::renderDataTable({
  DT::datatable(DataReactive()$comp_info,  extensions = 'Buttons',  options = list(
    dom = 'lBfrtip', buttons = c('csv', 'excel', 'print'), pageLength = 15))
})

output$data_wide <- DT::renderDataTable({
  data_w<-DataReactive()$data_wide
  data_w=round(data_w*1000)/1000
	DT::datatable(data_w, extensions = c('FixedColumns', 'Buttons'),
  options = list(
  	pageLength = 15,
  	dom = 'lBfrtip', buttons = c('csv', 'excel', 'print'),
    scrollX = TRUE,
    fixedColumns = list(leftColumns = 1)
  ))
})

output$ProteinGeneName <- DT::renderDataTable({
	DT::datatable(DataReactive()$ProteinGeneName, extensions = 'Buttons', options = list(
	  dom = 'lBfrtip', buttons = c('csv', 'excel', 'print'),
	  pageLength = 15),rownames= FALSE)
})

observeEvent(input$results, {
	DataIn <- DataReactive()
	results = DataIn$data_results 
	results[,sapply(results,is.numeric)] <- signif(results[,sapply(results,is.numeric)],3)
	saved_table$results <- results
})

observeEvent(input$sample, {
	saved_table$sample <- DataReactive()$MetaData
})

observeEvent(input$data_wide, {
	saved_table$data <- DataReactive()$data_wide
})

observeEvent(input$ProteinGeneName, {
	saved_table$ProteinGeneName <- DataReactive()$ProteinGeneName
})



