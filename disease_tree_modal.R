diseaseTreeModal <- function(failed = FALSE, msg = '',  init_code = '',  input_df = data.frame() ){
  modalDialog(
    
    #textInput("start_code", "", value = init_code),
    #collapsibleTreeOutput("disease_tree", height = "700px", width =
   #                         '1000px'),
    disease_tree <- renderCollapsibleTree({
      hh_collapsibleTreeNetwork(
        input_df,
        collapsed = TRUE,
        linkLength = 450,
        zoomable = FALSE,
        inputId = "selected_node",
        nodeSize = 'nodeSize',
        #nodeSize = 14,
        aggFun = 'identity',
        fontSize = 14
      )
    }),
    if (failed) {
      div(tags$b(msg, style = "color: red;"))
    },
    title = "Select Disease",
    footer = tagList(
      modalButton("Cancel"),
      actionButton("disease_selected", "OK")
    ),
    size = "l"
    
  )
}
