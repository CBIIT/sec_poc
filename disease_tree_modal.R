diseaseTreeModal <- function(failed = FALSE, msg = '',  init_code = '',  input_df = data.frame() ){
  modalDialog(
    
    #textInput("start_code", "", value = init_code),
    #collapsibleTreeOutput("disease_tree", height = "700px", width =
   #                         '1000px'),
    fluidPage(id = "treePanel",
              fluidRow(column(
                12,
                wellPanel(
                  id = "tPanel",
                  style = "overflow-y:scroll;  max-height: 600px; overflow-x:scroll; max-width: 2200px",
                  collapsibleTreeOutput("disease_tree", height = "800px", width =
                                          '2200px')
                )
              )),
              fluidRow(textOutput("gyn_selected"))
              
              ),
    #           
    # output$disease_tree <- renderCollapsibleTree({
    #   hh_collapsibleTreeNetwork( 
    #     input_df,
    #     collapsed = TRUE,
    #     linkLength = 450,
    #     zoomable = FALSE,
    #     inputId = "selected_node",
    #     nodeSize = 'nodeSize',
    #     #nodeSize = 14,
    #     aggFun = 'identity',
    #     fontSize = 14 #,
    #   #  width = '2000px',
    #   #  height = '700px'
    #   )})
    # 
    
    if (failed) {
      div(tags$b(msg, style = "color: red;"))
    },
    title = "Select Disease",
    footer = tagList(
      modalButton("Cancel"),
      actionButton("disease_selected", "Add Disease")
    ),
    size = "l"
    
  )

}
