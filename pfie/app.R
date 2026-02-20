# #Shiny app to display police firearm injury data collected from GVA and cleaned by Sierra-Arévalo et al.
# ####################################################

#When editing / testing, use below line in console to run app and have it autoupdate
#browser window where app is running. 
# shiny::runApp(launch.browser = TRUE)


## --- Hot reload (RStudio + external browser) ---
if (interactive()) {
  options(shiny.autoreload = TRUE)
  options(shiny.launch.browser = TRUE)  # open in your default browser
}

library(dplyr)
library(shiny)
library(shinydashboard)
library(leaflet)
library(leaflet.extras)
library(sp)
library(lubridate)
library(fontawesome)
library(readr)
library(plotly)
library(jsonlite)
library(ggplot2)
library(DT)

# Do NOT hard-require extrafont on shinyapps; it often breaks startup
if (requireNamespace("extrafont", quietly = TRUE)) {
  # optional: extrafont::loadfonts(quiet = TRUE)
}

data <- readr::read_csv("data/pfie20142020.csv", col_types = cols())
state_centroids <- readr::read_csv("data/statecentroids.csv", col_types = cols())

data <- data %>% mutate(date = as.Date(date))
statebounds <- readr::read_csv("data/statebounds.csv", col_types = cols())

# Merge centroids
data <- data %>% left_join(state_centroids, by = c("state" = "state"))

#Startup self-check
if (!interactive()) {
  message("=== PFIE startup on shinyapps ===")
  message("WD: ", getwd())
  message("Top-level files: ", paste(list.files(), collapse=", "))
  message("Data files: ", paste(tryCatch(list.files("data"), error=function(e) "NO data dir"), collapse=", "))
}

ui <- dashboardPage(
  dashboardHeader(),
  dashboardSidebar(
    dateRangeInput("dateRange", "Select Date Range:", start = "2014-01-01", end = "2020-12-31"),
    selectInput("state", "Select State:", choices = c("National", sort(unique(data$state)))),
    selectInput("agencyType", "Select Agency Type:", choices = c("All", "Local", "Sheriff", "State", "Special")),
    selectInput("injuryStatus", "Select Injury Status:", choices = c("All", "Fatal", "Nonfatal")),
    selectInput("fileFormat", "Select File Format:", choices = c("CSV", "JSON", "TXT"), selected = "CSV"),
    div(id = "downloadButtonContainer", downloadButton("downloadData", "Export Filtered Data", class = "download-button-class"))
  ),
  
  dashboardBody(
    tags$head(
      # MAP HEIGHT ------------------------------------------------------------
      tags$style(HTML("
        #pfiemap {
          height: 40vh !important;
        }
      ")),
      
      # FONT + BUTTONS --------------------------------------------------------
      tags$link(
        rel = "stylesheet",
        href = "https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;700&display=swap"
      ),
      tags$link(
        rel = "stylesheet",
        href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css"
      ),
      
      tags$style(HTML("
        body, .main-header, .navbar, .nav-tabs, .download-button-class, 
        .shiny-output-error, .shiny-output-error:before, .main-sidebar, 
        .content-wrapper, .control-sidebar, .info-box, .dataTables_wrapper {
          font-family: 'Roboto', sans-serif !important;
          }

        .wrapper {
          position: relative !important;
          overflow-y: hidden !important; 
          overflow-x: hidden !important;
        }

        .btn.btn-default.download-button-class, 
        .skin-blue .sidebar a#downloadData.btn.btn-default.download-button-class {
          background-color: #3c8dbc !important;
          color: #ffffff !important;
          width: 80% !important;
          margin: 10px auto !important;
          display: block;
          text-align: center;
        }
        
        .nav-tabs > li > a {
        font-family: 'Roboto', sans-serif;
        font-size: clamp(14px, 3vw, 18px);
        font-weight: 400;
        }
        
        .nav-tabs > li.active > a {
        font-weight: 600;
        }

        .btn.btn-default.download-button-class:hover,
        .skin-blue .sidebar a#downloadData.btn.btn-default.download-button-class:hover {
          background-color: #e07a00 !important;
          color: white !important;
        }
        
        /* BUTTON ROW LAYOUT customization. This affects layout of buttons */
        .button-row {
          display: flex;
          flex-wrap: wrap;
          column-gap: 10px;
          row-gap: 25px;
          
          justify-content: space-evenly;
        }
        
        .controls-container .slider-group .control-label {
          font-size: clamp(14px, 1.3vw, 18px);
          line-height: 1.5;
          margin-bottom: 4px;
      }
        
        /* Button customization: affects sizing and content of buttons themselves */
        .pfie-btn {
          padding: 8px 12px;
          font-size: clamp(12px, 1.2vw, 18px); 
          background-color: #3c8dbc !important; /*blue button background*/
          color: #ffffff !important; /* white button text*/
          border: 1.5px solid #ffffff !important; /* white button outline */
          border-radius:4px;
          cursor: pointer; 
          display: inline-flex;
          align-items: center;
          justify-content: center;
          gap: 6px;
          transition: background-color 0.15s ease, border-color .15s ease, color .15s ease;
        }
        
        .pfie-btn:hover{
          background-color: #357ca5 !important;
          color: #ffffff !important;
          border-color: #ffffff !important;
        }
        
        .pfie-btn i {
          width: 1.25em;
          text-align; cener; 
          margin: 0 !important;
          vertical-align: middle;
          font-size: 1em;
        }

        /* When the Freeze Map button activated, disable +/- buttons and dim them */
        #pfiemap.frozen .leaflet-control-zoom {
          pointer-events: none;
          opacity: 0.5;
        }
        
       
        /* Active state: icons red when button is 'on' */
        .btn-freeze.frozen i,
        .btn-cluster.cluster-on i {
          color: #cc0000;
        }
        
        /* Normalize Font Awesome icons inside buttons */
        .btn-cluster i,
        .btn-fitmap  i,
        .btn-freeze  i {
          width: 1.25em;
          text-align: center;
          margin: 0 !important;
          vertical-align: middle;
          font-size: 1em;
        }
        
        #pfiemap.frozen {
        outline: 3px solid #cc0000;     /* red border outline */
        transition: outline 0.1s ease;  /* smooth visual change */
        border-radius: 4px;             /* optional, to match Leaflet’s rounded corners */
              }
        
      ")),
      
      # PLOT TITLES + FONTS --------------------------------------------------
      tags$style(HTML("

        .plot-title {
          background-color: #ffffff;
          border-left: 4px solid #3c8dbc;
          padding: 8px 10px;
          font-size: clamp(14px, 1.2vw, 18px);
          font-weight: 400;
          color: #000;
          line-height: 1.3;
          white-space: normal;
          word-break: normal;
          overflow-wrap: break-word;
          margin: 0;
        }

        .plot-area { margin-top: 2px; }
        .tight-plot { margin-top: 0 !important; }

        .plot-area .html-widget,
        .plot-area .html-widget-container,
        .plot-area .plotly,
        .plot-area .js-plotly-plot {
          height: 100% !important;
          width: 100% !important;
        }
        
         .skin-blue .main-header .navbar .sidebar-toggle {
          background-color: #FF8C00 !important;
          color: #ffffff !important;
          border-radius: 5px;
          border: 1px solid #e07a00 !important;
          font-size: clamp(14px, 3vw, 20px);
          font-weight: 400;
          font-family: 'Roboto', sans-serif !important;
          display: flex;
          align-items: center;  
          justify-content: center;
          gap: 4px;
          letter-spacing: 0;
      }
        

        /* remove the default « » glyphs */
        .skin-blue .main-header .navbar .sidebar-toggle::before,
        .skin-blue .main-header .navbar .sidebar-toggle::after {
          display: none !important;
          content: none !important;
        }

        /* hover state */
        .skin-blue .main-header .navbar .sidebar-toggle:hover {
          background-color: #e07a00 !important;
          color: #fff !important;
          opacity: 1;
          text-decoration: none;
        }
        
       .pfie-table-caption {
          display: table-caption;
          caption-side: top;
          text-align: left;
          font-weight: 600;
          padding-bottom: 6px;
          font-size: clamp(13px, 2.2vw, 18px);
          white-space: normal;
       }
       
       .pfie-table-caption .pfie-info-icon {
          font-size: 15px;
          color: #3c8dbc;
          cursor:pointer; 
          margin-left: 6px;
       }
       
       .pfie-table-caption .pfie-info-icon:hover {
          color: #e07a00;
       }
       
       .pfie-tooltip {
          position: absolute;
          background: #ffffff;
          border: 1px solid #cccccc;
          padding: 6px 8px;
          font-size: 12px;
          border-radius: 4px;
          box-shadow: 0 1px 4px rgba(0,0,0,0.18);
          max-width: 260px;
          z-index: 9999;
          display: none;
          text-align: left;
       }
       
       .pfie-tooltip.pfie-visible {
          display: block;
        }
        
       /* Ensure DataTables responsive child rows wrap properly */
        table.dataTable.dtr-inline.collapsed tbody tr.child td.child {
          white-space: normal !important;
          word-break: break-word !important;
          overflow-wrap: break-word !important;
        }
      
        /* Also let the child-table itself expand and wrap */
        table.dataTable.dtr-inline.collapsed tbody tr.child ul.dtr-details li {
          white-space: normal !important;
          word-break: break-word !important;
          overflow-wrap: break-word !important;
        }
      
        /* Prevent horizontal scroll on child rows */
        table.dataTable.dtr-inline.collapsed tbody tr.child {
          overflow-x: visible !important;
        }
      
        /* Slightly indent child rows for readability */
        table.dataTable tbody tr.child td {
          padding-left: 12px !important;
        }

        /*Plot resizing based on screen size */ 
        .plot-area { height: clamp(280px, 32vh, 480px); }
        @media (max-width: 1199px) {
          .plot-area { height: clamp(300px, 38vh, 540px); }
        }
      
        
      @media (max-width: 768px) {

      /* lay out sliders + buttons side by side */
      .controls-container {
        display: flex;
        flex-direction: row;
        align-items: stretch;
        column-gap: 3%;
        
      }
    
      /* give sliders 45% of the width */
      .controls-container .slider-group {
        flex: 0 0 45%;
        max-width: 45%;
        
      }
    
      /* give buttons 50% of the width */
      .controls-container .button-row {
        flex: 0 0 50%;
        max-width: 50%;

        display: flex;
        flex-direction: column;
        justify-content: space-between;
        align-items: stretch;
        row-gap: 8px;
        margin-bottom: 5%;
        margin-top: 5%;
      }
    
      /* shrink button text/padding on mobile */
      .controls-container .button-row .pfie-btn {
        width: 100%; /* 100% of the column, so 50% of the full area */ 
        font-size: clamp(13px, 3vw, 18px);
        line-height: 1.5;
        white-space: nowrap;
      }
    
      /* optional: slightly smaller slider labels on mobile */
      .controls-container .slider-group .control-label {
        font-size: clamp(11px, 3vw, 18px);
        line-height: 1.5;
        margin-bottom: 4px;
        white-space: nowrap;
      }
    }
      
      ")),
      
      # CUSTOM ICON AND TEXT FOR FILTER MENU --------------------------
      tags$script(HTML("
        $(function() {
          var $toggle = $('.sidebar-toggle');
          $toggle.empty();
          $toggle.append(
            '<i class=\"fa-solid fa-filter\" aria-hidden=\"true\"></i>' +
            '<span class=\"toggle-label\" style=\"margin-left:6px;\">Filters</span>'
          );
        });
      ")),
      
      # HEADER RESIZE APP TITLE HEADER --------------------------------
      tags$script(HTML("
        $(document).ready(function() {
          function adjustHeaderAndSidebar() {
            var width = $(window).width();
            if (width < 768) {
              $('.main-header .logo')
                .text('PFIE')
                .css('font-size', '24px');

            } else {
              $('.main-header .logo')
                .text('Police Firearm Injury Explorer (PFIE)')
                .css('font-size', '18px');
            }
            
            $('.main-header .logo').css({
              'font-weight': 400,
              'font-family': 'Roboto',
              'line-height':'1',
              'height': 'fit-content',
              'padding': '10px',
              'display': 'block',
              'text-align': 'center'
            });
            var headerHeight = $('.main-header .logo').outerHeight();
            $('.sidebar-toggle').css({  
              'height': headerHeight,
              'align-items': 'center'
            });
          }
          adjustHeaderAndSidebar();
          $(window).on('resize', adjustHeaderAndSidebar);
        });
      ")),
      
      # LEAFLET FREEZE/UNFREEZE JS HANDLER -------------------------
      tags$script(HTML("
       Shiny.addCustomMessageHandler('leafletFreeze', function(isFrozen) {
        var widget = HTMLWidgets.find('#pfiemap');
        if (!widget || !widget.getMap) return;
        var map = widget.getMap();
        if (!map) return;
      
        var container = map.getContainer();
      
        // helper handlers we can add/remove
        if (!container._pfieWheelBlocker) {
          container._pfieWheelBlocker = function(e){
            e.preventDefault();
            e.stopImmediatePropagation();
            e.stopPropagation();
            return false;
          };
          container._pfieTouchBlocker = function(e){
            e.preventDefault();
            e.stopImmediatePropagation();
            e.stopPropagation();
            return false;
          };
        }
      
        // attach/remove listeners with capture + passive:false so preventDefault works
        function bindBlockers() {
          ['wheel','mousewheel','DOMMouseScroll'].forEach(function(ev){
            container.addEventListener(ev, container._pfieWheelBlocker, {capture:true, passive:false});
          });
          // belt & suspenders for touchpad/pinch
          ['touchstart','touchmove','gesturestart'].forEach(function(ev){
            container.addEventListener(ev, container._pfieTouchBlocker, {capture:true, passive:false});
          });
        }
        function unbindBlockers() {
          ['wheel','mousewheel','DOMMouseScroll'].forEach(function(ev){
            container.removeEventListener(ev, container._pfieWheelBlocker, {capture:true, passive:false});
          });
          ['touchstart','touchmove','gesturestart'].forEach(function(ev){
            container.removeEventListener(ev, container._pfieTouchBlocker, {capture:true, passive:false});
          });
        }
      
        if (isFrozen) {
          // Disable all Leaflet interactions
          map.dragging.disable();
          map.touchZoom.disable();
          map.doubleClickZoom.disable();
          map.scrollWheelZoom.disable();
          map.boxZoom.disable();
          map.keyboard.disable();
          if (map.tap) map.tap.disable();
      
          // Intercept at the container so nothing leaks through
          bindBlockers();
      
          // Visual state
          $('#pfiemap').addClass('frozen');
        } else {
          // Re-enable interactions
          map.dragging.enable();
          map.touchZoom.enable();
          map.doubleClickZoom.enable();
          map.scrollWheelZoom.enable();
          map.boxZoom.enable();
          map.keyboard.enable();
          if (map.tap) map.tap.enable();
      
          // Remove interceptors
          unbindBlockers();
      
          // Clear visual state
          $('#pfiemap').removeClass('frozen');
        }
      });
")),
      
      tags$script(HTML("
        Shiny.addCustomMessageHandler('toggleFreezeClass', function(isFrozen) {
          const btn = $('#freezeMap');
          if (isFrozen) btn.addClass('frozen');
          else btn.removeClass('frozen');
        });
")),
      
      #Custom message handler for cluster button being activated
      tags$script(HTML("
        Shiny.addCustomMessageHandler('toggleClusterClass', function(clusterOn) {
          const btn = $('#toggleClustering');
          if (clusterOn) {
            btn.addClass('cluster-on');
          } else {
            btn.removeClass('cluster-on');
          }
        });
    ")),
      
      # CUSTOM tooltip AND hover behavior for Data tab info button --------------------------
      tags$script(HTML("
          $(function() {
            // Single shared tooltip element
            var $tooltip = $('<div id=\"pfie-tooltip\" class=\"pfie-tooltip\"></div>').appendTo('body');
        
            function getText($icon) {
              // Cache the text from title into data- attribute, then strip title
              var txt = $icon.data('pfie-tooltip');
              if (!txt) {
                txt = $icon.attr('title') || '';
                $icon.data('pfie-tooltip', txt);
                $icon.removeAttr('title');  // avoid browser-native tooltip
              }
              return txt;
            }
        
            function showTooltip($icon) {
              var text = getText($icon);
              if (!text) return;
        
              var offset = $icon.offset();
              $tooltip
                .text(text)
                .addClass('pfie-visible')
                .css({
                  left: offset.left + 10,
                  top:  offset.top + 30
                });
            }
        
            function hideTooltip() {
              $tooltip.removeClass('pfie-visible');
            }
        
            // -------------------------
            // DESKTOP: hover behavior
            // -------------------------
            $('body').on('mouseenter', '.pfie-info-icon', function() {
              if (window.matchMedia('(hover: hover)').matches) {
                showTooltip($(this));
              }
            });
        
            $('body').on('mouseleave', '.pfie-info-icon', function() {
              if (window.matchMedia('(hover: hover)').matches) {
                hideTooltip();
              }
            });
        
            // -------------------------
            // MOBILE / CLICK behavior
            // -------------------------
        
            // Tap the icon: toggle tooltip
            $('body').on('click', '.pfie-info-icon', function(e) {
              var $icon = $(this);
              // Don't let the click fall through without us deciding behavior
              // but we do NOT call stopPropagation here, so the generic body
              // handler still runs and we control it there.
              if ($tooltip.hasClass('pfie-visible')) {
                hideTooltip();
              } else {
                showTooltip($icon);
              }
            });
        
            // Tap the tooltip itself: hide it
            $('body').on('click', '.pfie-tooltip', function(e) {
              hideTooltip();
            });
        
            // Tap anywhere else: hide tooltip, but ignore taps on icon or tooltip
            $('body').on('click', function(e) {
              var $target = $(e.target);
              if ($target.closest('.pfie-info-icon, .pfie-tooltip').length === 0) {
                hideTooltip();
              }
            });
          });
"))
    ),  # close tags$head
    
    # ------------------------------------------------------------------------
    tabsetPanel(
      tabPanel(
        "Map",
        fluidRow(column(12, leafletOutput("pfiemap"))),
        fluidRow(tags$div(style = "height: 15px;")),
        fluidRow(
          # LEFT: controls -- sliders and map buttons
          column(
            width = 6,
            div(
              class = "controls-container",
              style = "padding-right:0px;",
              div(class = "slider-group",
                fluidRow(
                  column(
                    width = 6,
                    sliderInput(
                      "markerSize", "Map Marker Size",
                      min = 1, max = 10, value = 1, step = 1
                    )
                  ),
                  column(
                    width = 6,
                    sliderInput(
                      "jitterScale", "Map Jitter",
                      min = 0, max = 10, value = 3, step = 0.5
                    )
                  )
                )
                ),
                tags$div(style = "height: 10px;"),

            # --- BUTTON ROW (ALL 3 BUTTONS) -------------------------------------
              div(
                class = "button-row",
                
                actionButton(
                  "toggleClustering",
                  label = "Enable Map Clustering",
                  icon  = icon("project-diagram", class = "cluster-icon"),
                  class = "pfie-btn btn-cluster"
                ),
                
                actionButton(
                  "fitAll",
                  label = "Fit Map to Filtered Cases",
                  icon  = icon("maximize", class = "fitmap-icon"),
                  class = "pfie-btn btn-fitmap"
                ),
                
                actionButton(
                  "freezeMap",
                  label = "Freeze Map View",
                  icon  = icon("snowflake", class = "freeze-icon"),
                  class = "pfie-btn btn-freeze"
                )
              ),
              tags$div(style = "height: 25px;")
            )
          ),
          # RIGHT: bar plot title + plot
          column(
            width = 6,
            div(
              class = "plot-wrap",
              uiOutput("barGraph_title"),
              div(
                class = "plot-area tight-plot",
                plotlyOutput("barGraph", height = "100%")
              )
            )
          )
        )
      ),
      
      
      tabPanel("Trends", plotOutput("trendsPlot")),
      tabPanel("Data", 
               tags$div(style = "height: 14px;"), #spacer between tabs and table
                        DT::dataTableOutput("table")),
      tabPanel("About PFIE",
               HTML("<div style='padding: 20px;'>
          <h2>About Police Firearm Injury Explorer (PFIE)</h2>
          <p>The Police Firearm Injury Explorer builds on data made available by the
          <a href='https://www.gunviolencearchive.org/about'>Gun Violence Archive (GVA)</a>.</p>
          <p>GVA is a non-partisan, non-profit organization that compiles information on incidents of gun violence from 
          <q>over 7,500 law enforcement, media, government and commercial sources daily in an effort to provide near-real time data about the results of gun violence.</q></p>

          <h3>Frequently Asked Questions</h3>
          <h4>What cases are included in the PFIE dataset?</h4>
          <p>PFIE was constructed using GVA data which recorded law enforcement officers who were victims of any type of firearm violence (e.g., firearm homicide, assault, accident, suicide).</p>
          <p>Cases included in our dataset include cases in which:</p>
          <ul>
            <li>Victim is a sworn, active duty law enforcement officer.</li>
            <li>Shot fatally or nonfatally.</li>
            <li>With a firearm.</li>
            <li>By a suspect.</li>
            <li>Somewhere on their body or on-person equipment (e.g., radio, ballistic helmet).</li>
          </ul>

          <p>We exclude cases in which:</p>
          <ul>
            <li>Victim was a retired law enforcement officer.</li>
            <li>Victim was off-duty when they were shot.</li>
            <li>Victim was a corrections officer or federal law enforcement officer (e.g., FBI, ATF, Marshals).</li>
            <li>Victim was shot by another law enforcement officer (i.e., blue-on-blue shootings).</li>
            <li>Victim shot themselves on accident or intentionally (e.g., training accident, accidental discharge, suicide).</li>
          </ul>

          <h4>Who created PFIE?</h4>
          <p><a href='https://www.sierraarevalo.com'>Michael Sierra-Arévalo</a> (University of Texas) and 
          <a href='https://www.jnix.netlify.app/about'>Justin Nix</a> (University of Nebraska - Omaha) 
          designed the coding scheme and led data cleaning/coding.</p>
          <p>Coding was supported by Aidan Bach, Tommy Flaherty, Ciara Garcia, 
          Kateryna Kaplun, Philip Phu Pham, and Jamie Villarreal. 
          </p>
          <p>The PFIE application was written by Michael Sierra-Arévalo.</p> 
          <p><b>Preferred Citation for the Police Firearm Injury Explorer (PFIE):</b></p>
          <p>Sierra-Arévalo, M., Nix, J., Bach, A., Flatherty, T., Garcia, C., Kaplun, K., Pham, P. P., & Villarreal, J. (2024). 
          The Police Firearm Injury Explorer. Retrieved from https://michaelsierraa.shinyapps.io/pfie/</p>
        </div>")
      )
    )  # close tabsetPanel
  )    # close dashboardBody
)      # close dashboardPage

# --------------------- SERVER --------------------------------------------
server <- function(input, output, session) {
  
  # =======================
  # REACTIVE DATA
  # =======================
  
  #Observer to see if map is frozen by user or not. 
  observeEvent(TRUE, {
    session$sendCustomMessage("leafletFreeze", FALSE)
  }, once = TRUE)
  
  filteredData <- reactive({
    filtered <- data %>%
      mutate(officerid = row_number()) %>%
      filter(date >= input$dateRange[1], date <= input$dateRange[2])
    
    if (input$state != "National") filtered <- filtered %>% filter(state == input$state)
    if (input$agencyType != "All") filtered <- filtered %>% filter(agencytypelabel == input$agencyType)
    if (input$injuryStatus == "Fatal")     filtered <- filtered %>% filter(status2 == 1)
    if (input$injuryStatus == "Nonfatal")  filtered <- filtered %>% filter(status2 == 2)
    
    incident_aggregates <- filtered %>%
      group_by(incidentid) %>%
      summarise(totalofficers = n(),
                totalfatal = sum(status2 == 1, na.rm = TRUE),
                totalnonfatal = sum(status2 == 2, na.rm = TRUE),
                .groups = "drop")
    
    filtered %>% left_join(incident_aggregates, by = "incidentid")
  })
  
  # Freeze/unfreeze state
  freezeMap <- reactiveVal(FALSE)

  
  # =======================
  # MAP BEHAVIOR HELPERS
  # =======================
  fatalColor <- "red"
  nonfatalColor <- "blue"
  
  # reactive toggle for clustering
  useClusters <- reactiveVal(FALSE)
  observeEvent(input$toggleClustering, { useClusters(!useClusters()) })
  observe({
    label_text <- if (useClusters()) "Disable Map Clustering" else "Enable Map Clustering"
    updateActionButton(session, "toggleClustering", label = label_text)
    
    session$sendCustomMessage("toggleClusterClass", useClusters())
    
  })
  
  # track whether user has moved the map
  userHasMovedMap <- reactiveVal(FALSE)
  lastFitAtMs     <- reactiveVal(0)
  nowMs <- function() as.numeric(Sys.time()) * 1000
  markProgrammaticFit <- function() lastFitAtMs(nowMs())
  
  # ignore bounds updates for ~300ms after our own fits
  observeEvent(input$pfiemap_bounds, {
    if ((nowMs() - lastFitAtMs()) > 300) {
      userHasMovedMap(TRUE)
    }
  }, ignoreInit = TRUE)
  
  # fit helpers ------------------------------------------------------------
  fitToState <- function(proxy, state) {
    markProgrammaticFit()
    if (identical(state, "National")) {
      proxy %>% fitToFiltered(leafletProxy("pfiemap"), filteredData())
      return(invisible(NULL))
    }
    bb <- statebounds[statebounds$state == state, ]
    if (nrow(bb) == 1 && all(c("x1","y1","x2","y2") %in% names(bb))) {
      proxy %>% fitBounds(lng1 = bb$x1, lat1 = bb$y1, lng2 = bb$x2, lat2 = bb$y2)
    } else {
      proxy %>% fitToFiltered(leafletProxy("pfiemap"), filteredData())
    }
    invisible(NULL)
  }
  
  fitToFiltered <- function(proxy, df, pad_frac = 0.05, single_zoom = 8) {
    # If National view, always fit to the continental + AK/HI box
    if (identical(input$state, "National")) {
      proxy %>% fitBounds(
        lng1 = -179,  # far west (Alaska)
        lat1 =  14,   # includes Hawaii and Puerto Rico
        lng2 =  -60,  # east (Atlantic coast)
        lat2 =  72    # north (Alaska)
      )
      return(invisible(NULL))
    }
    
    # If no valid points (e.g., empty filter), still show full U.S. extent
    if (nrow(df) == 0 || all(is.na(df$longitude)) || all(is.na(df$latitude))) {
      proxy %>% fitBounds(
        lng1 = -179, lat1 = 14,
        lng2 = -60,  lat2 = 72
      )
      return(invisible(NULL))
    }
    
    # ---- remainder of your existing logic below ----
    lon_rng  <- range(df$longitude, na.rm = TRUE)
    lat_rng  <- range(df$latitude,  na.rm = TRUE)
    lon_span <- lon_rng[2] - lon_rng[1]
    lat_span <- lat_rng[2] - lat_rng[1]
    
    if ((is.finite(lon_span) && lon_span == 0) && (is.finite(lat_span) && lat_span == 0)) {
      proxy %>% setView(lng = lon_rng[1], lat = lat_rng[1], zoom = single_zoom)
      return(invisible(NULL))
    }
    
    pad_lon <- max(lon_span * pad_frac, 1e-3)
    pad_lat <- max(lat_span * pad_frac, 1e-3)
    
    proxy %>% fitBounds(
      lng1 = lon_rng[1] - pad_lon,
      lat1 = lat_rng[1] - pad_lat,
      lng2 = lon_rng[2] + pad_lon,
      lat2 = lat_rng[2] + pad_lat
    )
    invisible(NULL)
  }
  
  # draw points ------------------------------------------------------------
  drawPoints <- function(proxy, df, radius, clustered, jitter_steps) {
    proxy %>% clearGroup("pfie_points") %>% clearMarkerClusters()
    if (nrow(df) == 0) return(invisible(NULL))
    
    diffs_nonzero <- function(v) { d <- diff(sort(unique(v))); d[d > 0] }
    lon_step <- suppressWarnings(median(diffs_nonzero(df$longitude), na.rm = TRUE))
    lat_step <- suppressWarnings(median(diffs_nonzero(df$latitude),  na.rm = TRUE))
    step_from_data <- max(lon_step, lat_step, na.rm = TRUE)
    step_from_view <- NA_real_
    if (!is.null(input$pfiemap_bounds)) {
      b <- input$pfiemap_bounds
      view_width <- abs(b$east - b$west)
      step_from_view <- view_width / 500
    }
    base_step <- if (!is.na(step_from_data) && is.finite(step_from_data) && step_from_data > 0) {
      step_from_data
    } else if (!is.na(step_from_view) && is.finite(step_from_view) && step_from_view > 0) {
      step_from_view
    } else {
      1e-05
    }
    jitter_amt <- (jitter_steps / 10) * base_step
    
    set.seed(1000 + as.integer(jitter_steps))
    df_plot <- df %>%
      mutate(
        plot_lon = if (jitter_amt > 0) jitter(longitude, amount = jitter_amt) else longitude,
        plot_lat = if (jitter_amt > 0) jitter(latitude,  amount = jitter_amt)  else latitude
      )
    
    if (clustered) {
      proxy %>%
        addCircleMarkers(
          data = df_plot,
          lng = ~plot_lon, lat = ~plot_lat,
          radius = radius,
          color = ~ifelse(statuslabel == "Fatal", fatalColor, nonfatalColor),
          popup = ~paste(
            "State:", state,
            "<br>Date:", date,
            "<br>Incident ID:", incidentid,
            "<br>Agency:", agencytypelabel,
            "<br>Injury Status:", statuslabel,
            "<br>Total Officers Shot:", totalofficers,
            "<br># Fatal:", totalfatal,
            "<br># Nonfatal:", totalnonfatal
          ),
          clusterOptions = markerClusterOptions(
            maxClusterRadius = 30, spiderfyOnMaxZoom = TRUE, singleMarkerMode = TRUE
          ),
          group = "pfie_points"
        )
    } else {
      proxy %>%
        addCircleMarkers(
          data = df_plot,
          lng = ~plot_lon, lat = ~plot_lat,
          radius = radius,
          color = ~ifelse(statuslabel == "Fatal", fatalColor, nonfatalColor),
          popup = ~paste(
            "State:", state,
            "<br>Date:", date,
            "<br>Incident ID:", incidentid,
            "<br>Agency:", agencytypelabel,
            "<br>Injury Status:", statuslabel,
            "<br>Total Officers Shot:", totalofficers,
            "<br># Fatal:", totalfatal,
            "<br># Nonfatal:", totalnonfatal
          ),
          group = "pfie_points"
        )
    }
  }
  
  # =======================
  # BASEMAP INITIALIZATION
  # =======================
  output$pfiemap <- renderLeaflet({
    leaflet(options = leafletOptions(
      zoomSnap = .25, zoomDelta = .25, minZoom = 2, maxZoom = 18
    )) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      addLegend(position = "bottomright", title = "Injury Status",
                colors = c("red", "blue"), labels = c("Fatal", "Nonfatal"), opacity = 1) %>%
      # Explicitly fit to world-ish bounds that include AK + HI
      fitBounds(lng1 = -179, lat1 = -14, lng2 = 179, lat2 = 72)
  })
  
  # =======================
  # OBSERVERS
  # =======================
  
  # 1. When the user selects a new state → zoom to that state
  observeEvent(input$state, {
    if (!freezeMap()) {
      userHasMovedMap(FALSE)
      fitToState(leafletProxy("pfiemap"), input$state)
    }
  }, ignoreInit = FALSE)
  
  # 2. When filtered data changes → redraw, adjust zoom only if user hasn't moved
  observeEvent(filteredData(), {
    df    <- filteredData()
    proxy <- leafletProxy("pfiemap")
    
    drawPoints(proxy, df,
               radius       = input$markerSize,
               clustered    = useClusters(),
               jitter_steps = input$jitterScale)
    
    # Only adjust the view if NOT frozen and the user hasn't moved the map
    if (!freezeMap() && !userHasMovedMap()) {
      if (identical(input$state, "National")) {
        fitToFiltered(proxy, df)
      } else {
        fitToState(proxy, input$state)
      }
    }
  }, ignoreInit = FALSE)
  
  # 3. “Fit to Selected Cases” button → always fit to filtered points
  observeEvent(input$fitAll, {
    # If frozen, unfreeze first
    if (freezeMap()) {
      freezeMap(FALSE)
      updateActionButton(session, "freezeMap", label = "Freeze Map View")
      session$sendCustomMessage("leafletFreeze", FALSE)
      session$sendCustomMessage("toggleFreezeClass", FALSE)
    }
    
    # Then proceed as usual
    if (identical(input$state, "National")) {
      fitToFiltered(leafletProxy("pfiemap"), filteredData())
    } else {
      fitToState(leafletProxy("pfiemap"), input$state)
    }
  })
  
  # 4. Redraw points if marker size, jitter, or clustering toggled
  observeEvent(list(input$markerSize, useClusters(), input$jitterScale), {
    leafletProxy("pfiemap") %>%
      { drawPoints(.,
                   filteredData(),
                   radius = input$markerSize,
                   clustered = useClusters(),
                   jitter_steps = input$jitterScale) }
  }, ignoreInit = FALSE)
  
  #5. Observing freeze map state for freeze map button display. 
  
  observeEvent(input$freezeMap, {
    freezeMap(!freezeMap())
    
    # label text flips exactly as before
    new_label <- if (freezeMap()) "Unfreeze Map View" else "Freeze Map View"
    updateActionButton(session, "freezeMap", label = new_label)
    
    # icon color via CSS class
    session$sendCustomMessage("toggleFreezeClass", freezeMap())
    
    # Leaflet interactions lock/unlock (your existing behavior)
    session$sendCustomMessage("leafletFreeze", freezeMap())
  })
  
  # =======================
  # BAR GRAPH
  # =======================
  output$barGraph <- renderPlotly({
    filtered_data <- filteredData()
    aggregated_data <- filtered_data %>%
      group_by(agencytypelabel, statuslabel) %>%
      summarise(count = n(), .groups = "drop")
    
    formatted_date_range <- paste(
      format(input$dateRange[1], "%Y-%m-%d"), "to", format(input$dateRange[2], "%Y-%m-%d"))
    state_lbl <- if (input$state == "National") "United States" else input$state
    
    bar_plot_title <- switch(
      input$injuryStatus,
      "All"      = paste("Fatal and Nonfatal Police Firearm Injuries by Agency Type —", state_lbl, formatted_date_range),
      "Fatal"    = paste("Fatal Police Firearm Injuries by Agency Type —", state_lbl, formatted_date_range),
      "Nonfatal" = paste("Nonfatal Police Firearm Injuries by Agency Type —", state_lbl, formatted_date_range)
    )
    
    output$barGraph_title <- renderUI({ div(class = "plot-title", bar_plot_title) })
    
    bar_ggplot <- ggplot(aggregated_data,
                         aes(x = agencytypelabel, y = count, fill = statuslabel,
                             text = paste("Agency Type:", agencytypelabel,
                                          "\nCount:", count,
                                          "\nInjury Status:", statuslabel))) +
      geom_bar(stat = "identity", position = position_dodge()) +
      scale_fill_manual(values = c("Fatal" = "red", "Nonfatal" = "blue")) +
      theme_minimal() +
      labs(x = "Agency Type", y = "Count", fill = "Injury Status") +
      theme(text = element_text(family = "Roboto"),
            axis.text.x = element_text(angle = 45, hjust = 1))
    
    ggplotly(bar_ggplot, tooltip = "text") %>%
      layout(title = NULL, margin = list(t = 0),
             font = list(family = "Roboto, sans-serif"),
             xaxis = list(titlefont = list(family = "Roboto, sans-serif"),
                          tickfont = list(family = "Roboto, sans-serif"),
                          title = list(standoff = 12)),
             yaxis = list(titlefont = list(family = "Roboto, sans-serif"),
                          tickfont = list(family = "Roboto, sans-serif")),
             legend = list(font = list(family = "Roboto, sans-serif")),
             hoverlabel = list(font = list(family = "Roboto, sans-serif"))) %>%
      config(displayModeBar = FALSE, responsive = TRUE)
  })
  
  #Creating a reactive title object to be called in Trends and Data tabs
  
  # =======================
  # SHARED TITLE LOGIC
  # =======================
  titleBase <- reactive({
    # Agency descriptor
    agency_desc <- switch(
      input$agencyType,
      "All"     = "Police",
      "Local"   = "Local Police",
      "Sheriff" = "Sheriff’s Deputies",
      "State"   = "State Police",
      "Special" = "Special Police"
    )
    
    # Injury descriptor
    injury_desc <- switch(
      input$injuryStatus,
      "All"      = "Fatal and Nonfatal Firearm Injuries",
      "Fatal"    = "Fatal Firearm Injuries",
      "Nonfatal" = "Nonfatal Firearm Injuries"
    )
    
    # State label
    state_lbl <- if (input$state == "National") "United States" else input$state
    
    # Date range
    formatted_date_range <- sprintf(
      "%s to %s",
      format(input$dateRange[1], "%Y-%m-%d"),
      format(input$dateRange[2], "%Y-%m-%d")
    )
    
    # Final base title (no "Monthly" here)
    sprintf(
      "%s %s — %s — %s",
      agency_desc,
      injury_desc,
      state_lbl,
      formatted_date_range
    )
  })
  
  # =======================
  # TRENDS PLOT
  # =======================
  output$trendsPlot <- renderPlot({
    trend <- filteredData()
    trend_aggregated <- trend %>%
      mutate(month = floor_date(date, "month")) %>%
      group_by(month, statuslabel, status2) %>%
      summarise(incident_sum = n(), .groups = 'drop')
    
    # Use shared title + add "Monthly"
    plot_title <- paste("Monthly", titleBase())
    
    x_min <- min(trend_aggregated$month)
    x_max <- max(trend_aggregated$month)
    
    ggplot(trend_aggregated, aes(x = month, y = incident_sum, color = statuslabel)) +
      geom_point() +
      geom_smooth(method = "loess", se = FALSE, aes(linetype = statuslabel)) +
      scale_color_manual(name = "Injury Status", values = c("Fatal" = "red", "Nonfatal" = "blue")) +
      scale_x_date(limits = c(x_min, x_max), date_breaks = "1 year", date_labels = "%Y") +
      scale_linetype_manual(name = "Injury Status", values = c("dashed", "dashed")) +
      theme_minimal() +
      theme(text = element_text(family = "Roboto"),
            plot.title = element_text(size = 20),
            axis.title.x = element_text(size = 16),
            axis.title.y = element_text(size = 16),
            axis.text.x = element_text(size = 14),
            axis.text.y = element_text(size = 14),
            legend.title = element_text(size = 16),
            legend.text = element_text(size = 14)) +
      labs(title = plot_title, x = "", y = "Frequency")
  })
  
  # =======================
  # DATA TABLE
  # =======================
  
  output$table <- DT::renderDataTable({
    if (is.null(filteredData()) || nrow(filteredData()) == 0) return(NULL)
    
    df <- filteredData() %>%
      select(
        incidentid, date, statuslabel, state,
        latitude, longitude, agencytypelabel, sources
      )
    
    df$latitude  <- format(df$latitude,  trim = TRUE, scientific = FALSE)
    df$longitude <- format(df$longitude, trim = TRUE, scientific = FALSE)
    
    # clickable sources
    df$sources <- vapply(
      df$sources,
      FUN = function(s) {
        if (is.na(s) || s == "") return("")
        urls <- strsplit(s, ",\\s*")[[1]]
        paste(
          sprintf("<a href='%1$s' target='_blank'>%1$s</a>", urls),
          collapse = "<br/>"
        )
      },
      FUN.VALUE = character(1L)
    )
    
    # 🔹 restore nice column headers
    colnames(df) <- c(
      "Incident ID",
      "Date",
      "Injury Status",
      "State",
      "Latitude",
      "Longitude",
      "Agency Type",
      "Sources"
    )
    
  DT::datatable(
    df,
    rownames  = FALSE,
    escape    = FALSE,
    caption   = tags$caption(
      class = "pfie-table-caption",
      HTML(paste0(
        titleBase(),
        " ",
        "<i class='fa-solid fa-circle-info pfie-info-icon'",
        "data-pfie-tooltip='Source links come from the Gun Violence Archive. ",
        "URLs are not permalinks and may become unavailable over time.'",
        "></i>"
      ))
    ),
    extensions = c("FixedHeader"),
    options = list(
      pageLength = 25,
      order      = list(list(2, "desc")),
      scrollX = TRUE, 
      fixedHeader = TRUE
      ),
    class = "cell-border stripe dt-responsive"  # <-- removed `nowrap`
  )
    })
  
  # =======================
  # DOWNLOAD HANDLER
  # =======================
  output$downloadData <- downloadHandler(
    filename = function() {
      paste0("pfie-data-", Sys.Date(), ".", switch(
        input$fileFormat,
        "CSV"  = "csv",
        "JSON" = "json",
        "TXT"  = "txt"
      ))
    },
    content = function(file) {
      df <- filteredData() %>%
        select(
          incidentid, date, statuslabel, state,
          latitude, longitude, agencytypelabel, sources
        )
      
      # Same column labels as the table
      colnames(df) <- c(
        "Incident ID",
        "Date",
        "Injury Status",
        "State",
        "Latitude",
        "Longitude",
        "Agency Type",
        "Sources"
      )
      
      switch(input$fileFormat,
             "CSV"  = write.csv(df, file, row.names = FALSE),
             "JSON" = writeLines(jsonlite::toJSON(df, pretty = TRUE), file),
             "TXT"  = write.table(df, file, row.names = FALSE))
    }
  )
}

shinyApp(ui, server)

