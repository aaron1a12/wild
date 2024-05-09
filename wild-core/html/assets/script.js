
/*
    Menu Functions
    ==============

    CreateMenu(strMenuId, strMenuTitle)
    OpenMenu(strMenuId, bOpen)
    SetElementTextByClass(strMenuId, strClass, strText)
    SetElementTextById(strMenuId, strId, strText)
    CreatePage(strPageId, iType)
    IsAnyMenuOpen()
*/

function IsRedM()
{
    return (typeof GetParentResourceName != 'undefined') ? true : false
}       

function SetVisible(bVisible) 
{
    if (IsAnyMenuOpen()) {
        //console.log("Menus are open");
       // return;

    }

    if (bVisible)
    {
        document.body.style.visibility = "visible";
    }
    else
    {
        setTimeout(function(){
            if (!document.body.classList.contains("visible"))
            {
                document.body.style.visibility = "hidden";
            }
        }, 1000);
    }

    if (bVisible) 
    {
        document.body.classList.add("visible");
    }
    else
    {
        document.body.classList.remove("visible");
    }
}



var menus = [];
var activeMenu = "";
var currentMenuId = "";
let bMenuLock = false;

var pageItemAutoId = 0

function CreateMenu(strMenuId)
{
    if (typeof menus[strMenuId] != "undefined")
    {
        return; // Existing menu
    }

    menus[strMenuId] = { 
        pages: [],
        root: "",
        currentPage: "",
        history: []
    }

    var menuDiv = document.createElement("DIV");
    menuDiv.classList.add("menu");
    menuDiv.id = 'menu_' + strMenuId;

    var menuBgDiv = document.createElement("DIV");
    menuBgDiv.classList.add("menuBg");
    menuDiv.appendChild(menuBgDiv);

    var menuBodyDiv = document.createElement("DIV");
    menuBodyDiv.classList.add("menuBody");
    menuDiv.appendChild(menuBodyDiv);

    // Menu Body
    {
        var menuHeaderDiv = document.createElement("DIV");
        menuHeaderDiv.classList.add("menuHeader");
        menuBodyDiv.appendChild(menuHeaderDiv);

        // Header 
        {
            var menuHeaderH1 = document.createElement("H1");
            menuHeaderDiv.appendChild(menuHeaderH1);
        }

        // Subtitle 
        {
            var menuSubtitle = document.createElement("H2");
            menuSubtitle.classList.add("menuSubtitle");
            menuBodyDiv.appendChild(menuSubtitle);
        }

        // Top Scroller Line
        {
            var menuScrollerTopDiv = document.createElement("DIV");
            menuScrollerTopDiv.classList.add("menuScrollerTop");
            menuScrollerTopDiv.appendChild(document.createElement("DIV"))
            menuScrollerTopDiv.appendChild(document.createElement("DIV"))
            menuScrollerTopDiv.appendChild(document.createElement("DIV"))
            menuBodyDiv.appendChild(menuScrollerTopDiv);            
        }

        // Main Area (Page Container)
        {
            var menuBodyMainAreaDiv = document.createElement("DIV");
            menuBodyMainAreaDiv.classList.add("menuBodyMainArea");
            menuBodyDiv.appendChild(menuBodyMainAreaDiv);

            menus[strMenuId].mainAreaElement = menuBodyMainAreaDiv;

            menuBodyMainAreaDiv.addEventListener("scroll", UpdateOverflowArrow);

            /* Menu items go here */
        }

        // Bottom Scroller Line
        {
            var menuScrollerBottomDiv = document.createElement("DIV");
            menuScrollerBottomDiv.classList.add("menuScrollerBottom");
            menuScrollerBottomDiv.appendChild(document.createElement("DIV"))
            menuScrollerBottomDiv.appendChild(document.createElement("DIV"))

            var rightDiv = document.createElement("DIV");
            {
                // Scroller count
                var menuScrollerCountDiv = document.createElement("DIV");
                menuScrollerCountDiv.classList.add("menuScrollerCount");
                menuScrollerCountDiv.innerText = "";
                rightDiv.appendChild(menuScrollerCountDiv);
            }

            menuScrollerBottomDiv.appendChild(rightDiv)

            menuBodyDiv.appendChild(menuScrollerBottomDiv);   
        }

        // Detail Pane
        {
            var menuDetailDiv = document.createElement("DIV");
            menuDetailDiv.classList.add("menuDetail");
            menuBodyDiv.appendChild(menuDetailDiv);            
        }

        // Bottom Desc
        {
            var menuItemDescriptionDiv = document.createElement("DIV");
            menuItemDescriptionDiv.classList.add("menuItemDescription");
            menuItemDescriptionDiv.innerText = "";
            menuBodyDiv.appendChild(menuItemDescriptionDiv);
        }
    }

    document.body.appendChild(menuDiv)
}

function OpenMenu(strMenuId, bOpen)
{
    // Close active menu
    if (activeMenu!="" && activeMenu.classList.contains("visible"))
    {
        activeMenu.classList.remove("visible");

        let menuDiv = activeMenu;
        setTimeout(function(){
            if (!menuDiv.classList.contains("visible"))
            {
                menuDiv.style.display = "none";
            }

            activeMenu = "";
            currentMenuId = "";
        }, 200);
    }

    if (!bOpen) return; 

    // Opening 

    currentMenuId = strMenuId;
    activeMenu = document.getElementById("menu_" + strMenuId);

    if (!activeMenu)
    {
        console.log("Attempted to open non-existent menu.");
        return;
    }

    activeMenu.style.display = "block";


    if (menus[strMenuId].root != "")
    {
        GoToPage(strMenuId, menus[strMenuId].root)
    }
    else
    {
        // No root page, open the first page in the list
        for (var key in menus[strMenuId].pages) {
            GoToPage(strMenuId, key)
            break;
        }
        
    }

    setTimeout(function(){
        activeMenu.classList.add("visible");
        bMenuLock = false
    }, 1);       
}

function SetElementTextByClass(strMenuId, strClass, strText)
{
    console.log(`#menu_${strMenuId} .${strClass}`)
    let el = document.querySelector(`#menu_${strMenuId} .${strClass}`);
    el.innerText = strText;
}

function SetElementTextById(strMenuId, strId, strText)
{
    let el = document.querySelector(`#menu_${strMenuId}_item_${strId} div`);
    el.innerText = strText;                
}

function SetMenuRootPage(strMenuId, strPageId)
{
    menus[strMenuId]["root"] = strPageId;
}

function CreatePage(strMenuId, strPageId, strPageTitle, strPageSubtitle, iType, iDetailPanelSize)
{
    if (typeof menus[strMenuId] == "undefined")
    {
        console.log("Error: non-existent parent menu");
        return; // non-existent parent menu
    }

    var pageDiv = document.createElement("DIV");
    pageDiv.className = "menuPage";

    menus[strMenuId]["pages"][strPageId] = {
        title: strPageTitle, 
        subtitle: strPageSubtitle,
        element: pageDiv,
        detailPanelSize: iDetailPanelSize,
        items: [],
        selectedItem: undefined
    }

    var mainArea = menus[strMenuId].mainAreaElement;

    // Detail Panel Size (safe values: 0-12)

    if (iDetailPanelSize > 12)
        iDetailPanelSize = 12;
    else if (iDetailPanelSize < 0)
        iDetailPanelSize = 0;
    
    // 55 = menuItem height
    mainArea.style.height = (55 * (13 - iDetailPanelSize)) + "px"

    menus[strMenuId].mainAreaElement.appendChild(pageDiv);
}

function EditPage(strMenuId, strPageId, strPageTitle, strPageSubtitle)
{
    if (menus[strMenuId] == undefined)
    {
        console.log("Error: non-existent parent menu");
        return; // non-existent parent menu
    }

    let page = menus[strMenuId]["pages"][strPageId];

    if (page == undefined)
        return;

    page.title = strPageTitle;
    page.subtitle = strPageSubtitle;

    var currentPage = menus[strMenuId].currentPage;

    if (currentPage == strPageId)
    {
        // Update titles

        let titleElement = document.querySelector(`#menu_${strMenuId} h1`);
        let menuSubtitleElement = document.querySelector(`#menu_${strMenuId} h2`);

        titleElement.innerText = page.title;
        menuSubtitleElement.innerText = page.subtitle;
    }
}

let navigationLock = false;

function GoToPage(strMenuId, strPageId, bGoingBack, bNoHistory)
{
    if (navigationLock) 
        return;

    navigationLock = true;

    var currentPage = menus[strMenuId].currentPage;
    if (currentPage != "") // Hide current page
    {
        let currentPageElement = menus[strMenuId]["pages"][currentPage].element;
        currentPageElement.style.display = "none";
    }

    // Set the page as current
    menus[strMenuId].currentPage = strPageId;
    currentPage = strPageId;


    let menuBodyMainArea = document.querySelector(`#menu_${strMenuId} .menuBodyMainArea`);
    menuBodyMainArea.classList.add("fade-out");

    setTimeout(()=>{
        menuBodyMainArea.classList.remove("fade-out");

        // Display it
        let currentPageElement = menus[strMenuId]["pages"][currentPage].element;
        currentPageElement.style.display = "block";

        let page = menus[strMenuId].pages[currentPage];

        // Update titles

        let titleElement = document.querySelector(`#menu_${strMenuId} h1`);
        let menuSubtitleElement = document.querySelector(`#menu_${strMenuId} h2`);

        titleElement.innerText = page.title;
        menuSubtitleElement.innerText = page.subtitle;

        // Select automatically any item

        if (page.selectedItem == undefined && page.items.length > 0)
        {
            SelectPageItem(strMenuId, currentPage, page.items[0].id);
        }
        else
        {
            SelectPageItem(strMenuId, currentPage, page.selectedItem);
        }

        UpdateOverflowArrow();

        if (!(bGoingBack)) // Not going back
        {
            if (!(bNoHistory))
            {
                // Add to history
                menus[strMenuId].history.push(strPageId);
            }
        }
        
        navigationLock = false
    }, 100);
}


function GoBack()
{
    if (currentMenuId!="")
    {
        let menu = menus[currentMenuId];
        
        if (menu.history.length > 1) // We have history
        {
            let pageBefore = menu.history[menu.history.length-2];

            // Go
            GoToPage(currentMenuId, pageBefore, true);

            if (IsRedM())
                fetch(`https://${GetParentResourceName()}/playNavBackSound`);
        }
        else // Close
        {
            if (IsRedM())
                fetch(`https://${GetParentResourceName()}/closeAllMenus`);
        }

        // Remove from history
        menus[currentMenuId].history.pop();
    }
}

function ClearHistory()
{
    if (currentMenuId!="")
    {
        let menu = menus[currentMenuId];
        
        if (menu.history.length > 1) // We have history
        {
            menus[currentMenuId].history = [];
        }       
    }
}

function CreatePageItem(strMenuId, strPageId, strItemId, extraItemParams)
{
    let page = menus[strMenuId]["pages"][strPageId];

    let itemDiv = document.createElement("DIV");
    itemDiv.classList.add("menuItem");

    let id = (strItemId != 0 && strItemId != "") ? strItemId : pageItemAutoId+"";
    pageItemAutoId++;

    itemDiv.id = `menu_${strMenuId}_item_${id}`;

    {
        // Menu Item Content
        var itemContentDiv = document.createElement("DIV");
        itemContentDiv.innerText = extraItemParams.text;
        itemDiv.appendChild(itemContentDiv);
    }

    itemDiv.addEventListener("mouseenter", (evt)=>{
        SelectPageItem(strMenuId, strPageId, id);
    });

    itemDiv.addEventListener("click", (evt)=>{
        if (IsRedM())
            fetch(`https://${GetParentResourceName()}/playNavEnterSound`);

        TriggerSelectedItem();
    });

    page.items.push({
        id: id,
        element: itemDiv,
        extra: extraItemParams,
    });

    page.element.appendChild(itemDiv); 
    
    // If we're the first item in the page

    if (page.selectedItem == undefined)
    {
        SelectPageItem(strMenuId, strPageId, id);
    }
}

function DestroyPageItem(strMenuId, strPageId, strItemId)
{
    if (menus[strMenuId] == undefined)
        return;

    let page = menus[strMenuId]["pages"][strPageId];

    if (page == undefined)
        return;

    for (var i=0; i<page.items.length; i++)
    {
        if (page.items[i].id == strItemId)
        {
            let item = page.items[i];

            // Are we deleting a selected item?
            if (i > 0 && page.selectedItem == strItemId)
            {
                // Select item behind it
                SelectPageItem(strMenuId, strPageId, page.items[i-1].id);
            }

            item.element.remove();
            
            page.items.splice(i, 1);
            break;
        }
    }
}

function SelectPageItem(strMenuId, strPageId, strItemId)
{
    let page = menus[strMenuId]["pages"][strPageId];
    let element = undefined;
    let itemIndex = -1;

    for (var i=0; i<page.items.length; i++)
    {
        if (page.items[i].id == page.selectedItem)
        {
            page.items[i].element.classList.remove("selected");
        }

        if (page.items[i].id == strItemId)
        {
            element = page.items[i].element;
            element.classList.add("selected");
            itemIndex = i;
        }
    }

    if (itemIndex == -1)
        return; // no item found

    page.selectedItem = strItemId;

    // Scroll if not visible (list menus only)

    var mainAreaCont = element.parentElement.parentElement;

    var upperBound = mainAreaCont.scrollTop;
    var lowerBound = upperBound + mainAreaCont.offsetHeight;

    var elementTop = element.offsetTop;
    var elementBottom = elementTop + element.offsetHeight;

    var bElementIsVisible = (elementTop >= upperBound && elementBottom <= lowerBound);
   
    if (bElementIsVisible == false)
    {
        var scrollAmount = (elementBottom >= lowerBound) ? elementBottom-lowerBound : elementTop-upperBound;

        mainAreaCont.scrollTo({
            top: mainAreaCont.scrollTop+scrollAmount,
            behavior: "smooth",
        });
    }

    // Update description (under detail pane)
    let descElement = document.querySelector(`#menu_${strMenuId} .menuItemDescription`);
    let descTxt = page.items[itemIndex].extra.description;

    if (descTxt != undefined)
        descElement.innerText = page.items[itemIndex].extra.description;
    else
        descElement.innerText = "";

    let menuScrollerCount = document.querySelector(`#menu_${currentMenuId} .menuScrollerCount`);
    
    if (menuScrollerCount)
        menuScrollerCount.innerText = (itemIndex+1) + " of " + page.items.length;
}

function UpdateOverflowArrow()
{
    let menu = menus[currentMenuId]
    if (menu == undefined)
        return;

    var currentPage = menu.currentPage;       
    let page = menu["pages"][currentPage];

    if (page == undefined)
        return

    let mainAreaCont = document.querySelector(`#menu_${currentMenuId} .menuBodyMainArea`);    

    var upperBound = mainAreaCont.scrollTop;
    var lowerBound = upperBound + mainAreaCont.offsetHeight;

    // Update scroll overflow arrow
    var bItemsBeforeClipped = false;
    var bItemsAfterClipped = false;

    for (var i=0; i<page.items.length; i++)
    {
        var el = page.items[i].element;
        var elTop = el.offsetTop;
        var elBottom = elTop + el.offsetHeight;
        
        if (!(elTop >= upperBound && elBottom <= lowerBound)) // not in bounds
        {
            if (elTop < upperBound)
                bItemsBeforeClipped = true;

            if (elTop > lowerBound) 
                bItemsAfterClipped = true;

            if (bItemsBeforeClipped && bItemsAfterClipped)
                break;
        }
    }

    let menuScrollerTop = document.querySelector(`#menu_${currentMenuId} .menuScrollerTop`);
    let menuScrollerBottom = document.querySelector(`#menu_${currentMenuId} .menuScrollerBottom`);

    if (bItemsBeforeClipped)
        menuScrollerTop.classList.add("arrow");
    else
        menuScrollerTop.classList.remove("arrow");

    if (bItemsAfterClipped)
        menuScrollerBottom.classList.add("arrow");
    else
        menuScrollerBottom.classList.remove("arrow");
}

function MoveSelection(bForward)
{ 
    let menu = menus[currentMenuId]
    if (menu == undefined)
    {
        console.log("Unable to move select since currentMenuId is undefined.");
        return;
    }

    var currentPage = menu.currentPage;       
    let page = menu["pages"][currentPage];

    if (page == undefined)
        return;

    if (page.items.length == 0)
        return;

    let itemToSelect = undefined;

    if (page.selectedItem == undefined)
    {
        itemToSelect = page.items[0].id;
    }
    else
    {
        for (var i=0; i<page.items.length; i++)
        {
            if (page.items[i].id == page.selectedItem)
            {
                var index = (bForward) ? i+1 : i-1;

                
                if (page.items[index] == undefined)
                {
                    index = (bForward) ? 0 : page.items.length-1;
                }

                itemToSelect = page.items[index].id;
                break;
            }
        }    
    }
    
    SelectPageItem(currentMenuId, currentPage, itemToSelect);    
    
    /*if (IsRedM())
    {
        if (bForward)
            fetch(`https://${GetParentResourceName()}/playNavDownSound`);
        else
            fetch(`https://${GetParentResourceName()}/playNavUpSound`);
    }*/
}

let lastTriggerTime = 0

function TriggerSelectedItem()
{ 
    const elapsedMs = Date.now() - lastTriggerTime;

    if (elapsedMs < 500)
        return;

    lastTriggerTime = Date.now();

    let menu = menus[currentMenuId]
    if (menu == undefined)
    {
        console.log("currentMenuId is undefined.");
        return;
    }

    var currentPage = menu.currentPage;       
    let page = menu["pages"][currentPage];

    if (page == undefined)
    {
        console.log("currentPage is undefined.");
        return
    }

    if (page.selectedItem == undefined)
        return;   

    if (IsRedM()) 
    {
        fetch(`https://${GetParentResourceName()}/triggerSelectedItem`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                itemId: page.selectedItem
            })
        });
    }
    else // Chrome debugging
    {
        for (var i=0; i<page.items.length; i++)
        {
            if (page.items[i].id == page.selectedItem)
            {
                if (page.items[i].extra.action != undefined)
                    page.items[i].extra.action()
                break;
            }
        }
        
    }
}

function SetPageItemExtraParams(strMenuId, strPageId, strItemId, extraItemParams)
{
}

function IsAnyMenuOpen()
{
    return (activeMenu!="" && activeMenu.classList.contains("visible"))
}

function DestroyMenuAndData(strMenuId)
{
    if (menus[strMenuId] == undefined)
        return;

    if (currentMenuId==strMenuId)
        OpenMenu(strMenuId, false);    

    var menuEl = document.getElementById('menu_' + strMenuId);
    menuEl.remove();

    menus[strMenuId] = undefined;
}

window.addEventListener("load", (event) => {
    if (!IsRedM())
    {
        
        document.body.classList.add("not-redm")

        document.getElementById("moneyDollars").innerText = "0";
        document.getElementById("moneyCents").innerText = "00";

        SetVisible(true);

        setTimeout(function(){
            //SetVisible(false);
        }, 1000);
    }
});


if (IsRedM())
{
    // 4K fix
    var x = (window.screen.width / 1920);
    document.body.style.zoom = x;
}
else
{
    // Simulate RedM zoom for chrome
    document.body.style.zoom = window.screen.width / 1920;

    CreateMenu("onlineMenu");
    //SetElementTextByClass("onlineMenu", "menuSubtitle", "Not in faction")
    CreatePage("onlineMenu", "root", "CRAFTING\n UPGRADES", "Not in faction", 0, 4);

    SetMenuRootPage("onlineMenu", "root");

    CreatePageItem("onlineMenu", "root", "btnFoobar", {
        text: "Foobar",
        description: "Attempt to FUBAR the server.",
        action: ()=>{
            GoToPage("onlineMenu", "test_page");
        }
    });
    
    for (var i=0; i < 20; i++) {
        var params = {};
        params.text = `Menu Item #${i}`;
        //params.description = `Some description #${i}`;

        CreatePageItem("onlineMenu", "root", 0, params);
    }

    CreatePage("onlineMenu", "test_page", "Test Page", "Lorem ipsum", 0, 4);

    CreatePageItem("onlineMenu", "test_page", "btnFoobar", {
        text: "Nothing here",
        description: "Select to go back",
        action: ()=>{
            GoToPage("onlineMenu", "root");
        }
    });
    
    OpenMenu("onlineMenu", true);

    setTimeout(function(){
        //OpenMenu("debug1", false);
        //DestroyMenuAndData("onlineMenu");
    }, 1000);
    
}

window.addEventListener('message', function(event) {

    if (event.data.cmd == "ping")
    {
        console.log("Ping received.")
    }


    if (event.data.cmd == "setVisibility")
    {
        SetVisible(event.data.visible);
    }

    if (event.data.cmd == "setMoneyAmount")
    {

        let USDollar = new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
        });

        var money = USDollar.format(event.data.amount).replace('$','');
        money = money.split(".");

        document.getElementById("moneyDollars").innerText = money[0];
        document.getElementById("moneyCents").innerText = money[1];
    }

    if (event.data.cmd == "createMenu")
    {
        CreateMenu(event.data.menuId, event.data.menuTitle);
    }

    if (event.data.cmd == "openMenu")
    {
        OpenMenu(event.data.menuId, event.data.open);
    }

    if (event.data.cmd == "setElementTextByClass")
    {
        SetElementTextByClass(event.data.menuId, event.data.class, event.data.text);
    }

    if (event.data.cmd == "setElementTextById")
    {
        SetElementTextById(event.data.menuId, event.data.id, event.data.text);
    }

    if (event.data.cmd == "createPage")
    {
        CreatePage(event.data.menuId, event.data.pageId, event.data.pageTitle, event.data.pageSubtitle, event.data.type, event.data.detailPanelSize);
    }

    if (event.data.cmd == "editPage")
    {
        EditPage(event.data.menuId, event.data.pageId, event.data.pageTitle, event.data.pageSubtitle);
    }

    if (event.data.cmd == "goToPage")
    {
        GoToPage(event.data.menuId, event.data.pageId, event.data.noHistory);
    }

    if (event.data.cmd == "goBack")
    {
        GoBack();
    }

    if (event.data.cmd == "clearHistory")
    {
        ClearHistory();
    }

    if (event.data.cmd == "setMenuRootPage")
    {
        SetMenuRootPage(event.data.menuId, event.data.pageId);
    }

    if (event.data.cmd == "createPageItem")
    {
        CreatePageItem(event.data.menuId, event.data.pageId, event.data.itemId, event.data.extraItemParams);
    }

    if (event.data.cmd == "destroyPageItem")
    {
        DestroyPageItem(event.data.menuId, event.data.pageId, event.data.itemId)
    }

    if (event.data.cmd == "moveSelection")
    {
        MoveSelection(event.data.forward);
    }

    if (event.data.cmd == "triggerSelectedItem")
    {
        TriggerSelectedItem();
    }

    if (event.data.cmd == "destroyMenuAndData")
    {
        DestroyMenuAndData(event.data.menuId);
    }
});


document.onkeydown = function(evt) {
    switch (evt.key) {
    case 'Escape':

        if (currentMenuId!="")
        {
            let menu = menus[currentMenuId]
            let history = menu.history;

            if (history.length == 1)
            {
                //fetch(`https://${GetParentResourceName()}/closeAllMenus`);
            }
            else
            {
                //GoBack();


            }
        }
        
        break;

    case 'ArrowDown':
        if (!IsRedM()) MoveSelection(true);
        break;
    case 'ArrowUp':
        if (!IsRedM()) MoveSelection(false);
        break; 
    case 'Enter':
        if (!IsRedM()) TriggerSelectedItem();
        break; 
    }
};

document.addEventListener("wheel", (evt) => {
    MoveSelection((evt.deltaY/100)+1)
});