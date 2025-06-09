 AdminMissionElementsList = AdminMissionElementsList or {}

function AdminMissionElementsList:init()
	Input:keyboard():add_trigger(Idstring("f10"), callback(self, self, "setup"))  --Toggle Keybind
	Input:keyboard():add_trigger(Idstring("esc"), callback(self, self, "check_hide"))  --Hide Keybind
end

function AdminMissionElementsList:setup()
	self._mission_element_h = 30
	self._base_info_w = 200
	self._base_info_h = 30
	self._main_layer = 500
	self._ui = {}
	self._saved_search = nil
	self._selected_panel = {}
	self._on_mouse_panel = {}
	self._info_class = {}

	self._value_exclude = {
		"execute_on_startup"
	}

	self:switch()
end

function AdminMissionElementsList:switch()
	if self._selected then
		return
	end

	if self._enabled then
		self:hide()
	else
		self:show()
	end
end

function AdminMissionElementsList:show()
	self._ws = managers.gui_data:create_fullscreen_workspace({})

	self:show_mission_elements()

	-- set controller
	if game_state_machine then
		game_state_machine:current_state():set_controller_enabled(not managers.player:player_unit())  --锁定玩家视角
	end

	self._mouse_id = self._mouse_id or managers.mouse_pointer:get_id()
	self._mouse_data = {
		mouse_move = callback(self, self, "mouse_moved"),
		mouse_press = callback(self, self, "mouse_pressed"),
		mouse_release = callback(self, self, "mouse_released"),
		mouse_click = callback(self, self, "mouse_clicked"),
		id = self._mouse_id,
		menu_ui_object = self
	}
	managers.mouse_pointer:use_mouse(self._mouse_data)

	local controller = managers.controller:get_controller_by_name("MenuManager")
	
	if controller then
		controller:set_enabled(false)
	end

	if managers.menu and managers.menu.active_menu and managers.menu:active_menu() and managers.menu:active_menu().input then
		managers.menu:active_menu().input:set_back_enabled(false)
		managers.menu:active_menu().input:accept_input(false)
	end

	self._enabled = true
end

function AdminMissionElementsList:hide()
	if not self._enabled or self._selected then
		return
	end

	if self._ws then
		self._ws:hide()
		managers.gui_data:destroy_workspace(self._ws)
		self._ws = nil
	end

	managers.mouse_pointer:remove_mouse(self._mouse_data)

	if game_state_machine then
		game_state_machine:current_state():set_controller_enabled(true)  --恢复玩家视角
	end

	local controller = managers.controller:get_controller_by_name("MenuManager")
	
	if controller then
		controller:set_enabled(true)
	end

	if managers.menu and managers.menu.active_menu and managers.menu:active_menu() and managers.menu:active_menu().input then
		managers.menu:active_menu().input:set_back_enabled(true)
		managers.menu:active_menu().input:accept_input(true)
	end

	self._enabled = false
end

function AdminMissionElementsList:check_hide()
	if not self._enabled then
		return
	end

	if self._selected then
		return
	end

	if self._mission_element_searchbox._focus then
		return
	end

	self:hide()
end

function AdminMissionElementsList:mouse_moved(o, x, y)
	self._mouse_inside = false

	if not self._selected then
		if game_state_machine then
			game_state_machine:current_state():set_controller_enabled(not managers.player:player_unit())  --锁定玩家视角
		end

		self._elements_scroll:mouse_moved(o, x, y)

		for _, cls in pairs(self._info_class) do
			self._mouse_inside = cls:mouse_moved(o, x, y) and true or self._mouse_inside
		end

		---[[ Mission Elements List Mouse Moved
		self._touch_element_item = nil
		if self._scroll_panel:inside(x, y) then  --如果鼠标在列表内
			local item = self:get_panel_under_mouse(x, y)  -- 检测有没有鼠标有没有在其中一个item之上

			if item then
				self._mouse_inside = true
				self._touch_element_item = item
			end
		end

		-- 如果鼠标在滑槽上就设置鼠标为link
		if self._elements_scroll._scroll._scroll_bar:inside(x, y) or self._elements_scroll._scroll._grabbed_scroll_bar then
			self._mouse_inside = true
		end

		-- 设置显示鼠标之下UI的碰撞背景
		self:update_list_rect("mouse_moved")

		local inside = alive(self._mission_element_searchbox.panel) and self._mission_element_searchbox.panel:inside(x, y) or false

		if inside and not self._mission_element_searchbox._focus then
			self._mouse_inside = true
		end

		if self._selected then
			self._mouse_inside = false
		end

		-- Mission Elements List Mouse Moved ]]
	end

	if self._mouse_inside then
		managers.mouse_pointer:set_pointer_image("link")
	else
		managers.mouse_pointer:set_pointer_image("arrow")
	end
end

function AdminMissionElementsList:mouse_pressed(o, button, x, y)
	-- 主要检测有没有info的状态属于被编辑中，然后只执行正在编辑中的info
	local editing_cls = nil
	for _, cls in pairs(self._info_class) do
		if cls._editing then
			editing_cls = cls
		end
	end

	for _, cls in pairs(self._info_class) do
		if editing_cls then
			if alive(cls:panel()) and editing_cls == cls then
				cls:mouse_pressed(button, x, y)
			end
		elseif alive(cls:panel()) then
			cls:mouse_pressed(button, x, y)
		end
	end

	if editing_cls then
		return
	end

	-- 手动设置滚轮函数的检测执行
	if button == Idstring("mouse wheel up") then
		return self:mouse_wheel_up(x, y)
	elseif button == Idstring("mouse wheel down") then
		return self:mouse_wheel_down(x, y)
	end

	if button == Idstring("0") then  -- 检测鼠标左键
		-- 检测并设置当前点击的element
		if self._touch_element_item then
			local element = managers.mission:get_element_by_id(tonumber(self._touch_element_item:name()))
			self:set_element_info(element, self._ui.info, self._ui.title)
		end

		-- 以最优化的方式设置背景图层
		self:update_list_rect("mouse_pressed")
	end

	self._elements_scroll:mouse_pressed(button, x, y)  --手动执行滑动列表的鼠标点击事件
	self._mission_element_searchbox:mouse_pressed(button, x, y)  --手动执行搜索框的鼠标点击事件
end

function AdminMissionElementsList:mouse_released(o, button, x, y)
	self._elements_scroll:mouse_released(button, x, y)

	for _, cls in pairs(self._info_class) do
		cls:mouse_released(button, x, y)
	end
end

function AdminMissionElementsList:mouse_clicked(o, button, x, y)
	self._elements_scroll:mouse_clicked(o, button, x, y)
end

function AdminMissionElementsList:mouse_wheel_up(x, y)
	if self._elements_scroll._scroll:panel():inside(x, y) then
		self._elements_scroll:mouse_wheel_up(x, y)
	end
end

function AdminMissionElementsList:mouse_wheel_down(x, y)
	if self._elements_scroll._scroll:panel():inside(x, y) then
		self._elements_scroll:mouse_wheel_down(x, y)
	end
end

function AdminMissionElementsList:update_list_rect(type)
	if type == "mouse_moved" then
		if self._touch_element_item then
			if self._on_mouse_panel[1] ~= self._touch_element_item then
				table.insert(self._on_mouse_panel, 1, self._touch_element_item)
				table.remove(self._on_mouse_panel, 3)

				for k, item in ipairs(self._on_mouse_panel) do
					if item and alive(item) and item:child("bg") and self._selected_panel[1] ~= item then
						if k == 1 then
							item:child("bg"):set_visible(true)
							item:child("bg"):set_alpha(0.5)
						else
							item:child("bg"):set_visible(false)
						end
					end
				end
			end
		else
			for k, item in ipairs(self._on_mouse_panel) do
				if alive(item) and self._selected_panel[1] ~= item then
					item:child("bg"):set_visible(false)
				end
			end

			self._on_mouse_panel = {}
		end
	elseif type == "mouse_pressed" then
		if self._touch_element_item and self._selected_panel[1] ~= self._touch_element_item then
			table.insert(self._selected_panel, 1, self._touch_element_item)
			table.remove(self._selected_panel, 3)

			for k, item in ipairs(self._selected_panel) do
				if item and alive(item) and item:child("bg") then
					if k == 1 then
						item:child("bg"):set_visible(true)
						item:child("bg"):set_alpha(0.7)
					else
						item:child("bg"):set_visible(false)
					end
				end
			end
		end
	end
end

--获得当前鼠标下的element的panel（性能优化，避免遍历全部）
function AdminMissionElementsList:get_panel_under_mouse(x, y)
	if self._elements_scroll:items()[1] then
		local top = self._elements_scroll:items()[1]:top()
		local bottom = self._elements_scroll:items()[1]:bottom()
		local in_vis_top = (bottom <= 0) and math.round(-top / self._mission_element_h) or 0

		for key, panel in ipairs(self._elements_scroll:items()) do   
			if self._elements_scroll:items()[key + in_vis_top] and self._elements_scroll:items()[key + in_vis_top]:inside(x, y) then
				return self._elements_scroll:items()[key + in_vis_top]
			end
		end
	end
end

function AdminMissionElementsList:show_mission_elements()
	self._ui.mission_element = self._ws:panel():panel({
		layer = self._main_layer,
		w = 300,
		h = 600
	})

	self._ui.mission_element:set_center_y(self._ws:panel():center_y())
	self._ui.mission_element:set_left(self._ws:panel():left()+100)

	self._scroll_panel = self._ui.mission_element:panel({
		w = self._ui.mission_element:w(),
		h = self._ui.mission_element:h() - 50
	})

	-- Mission Elements Scroll Bar
	self._elements_scroll = ScrollItemList:new(self._scroll_panel, {
		scrollbar_padding = 0,
		bar_minimum_size = 16,
		padding = 0,
		w = self._scroll_panel:w(),
		h = self._scroll_panel:h(),
		input_focus = true
	}, {
		padding = 0
	})

	---[[ Element Info Panel 元素信息面板
	self._ui.info = self._ws:panel():panel({
		visible = false,
		layer = self._main_layer,
		w = 600,
		h = self._elements_scroll:canvas():h()
	})

	self._ui.info:set_left(self._ui.mission_element:right())
	self._ui.info:set_top(self._ui.mission_element:top())

	local info_rect = self._ui.info:bitmap({
		render_template = "VertexColorTexturedBlur3D",
		texture = "guis/textures/test_blur_df",
		w = self._ui.info:w(),
		h = self._ui.info:h(),
		layer = -2,
		color = Color.white
	})

	BoxGuiObject:_create_side(self._ui.info, "left", 1, false, false)
	BoxGuiObject:_create_side(self._ui.info, "right", 1, false, false)
	BoxGuiObject:_create_side(self._ui.info, "top", 1, false, false)
	BoxGuiObject:_create_side(self._ui.info, "bottom", 1, false, false)
	--Element Info Panel 元素信息面板 ]]

	self._ui.title = self._ws:panel():panel({
		visible = false,
		layer = self._main_layer,
		w = self._ui.info:w(),
		h = 50
	})

	self._ui.title:set_left(self._ui.info:left())
	self._ui.title:set_bottom(self._ui.info:top())

	local title_text = self._ui.title:text({
		name = "text",
		color = Color.white,
		vertical = "center",
		valign = "left",
		align = "left",
		halign = "center",
		font = tweak_data.hud_players.ammo_font,
		text = "Unknown",
		font_size = 30
	})

	title_text:set_bottom(self._ui.title:bottom())

	self._elements_scroll:add_lines_and_static_down_indicator()
	for name, data in pairs(managers.mission:scripts()) do
		for id, element in pairs(data:elements()) do
			local item = self._elements_scroll:add_item(self:set_element_panel(self._elements_scroll:canvas(), {
				element = element,
				h = self._mission_element_h
			}))
		end
	end

	if SearchBoxGuiObject and managers.menu:is_pc_controller() then
		self._mission_element_searchbox = SearchBoxGuiObject:new(self._ui.mission_element, self._ws, self._saved_search)
		self._mission_element_searchbox.panel:set_center_x((self._scroll_panel:w() - 20) / 2)
		self._mission_element_searchbox.panel:set_top(self._scroll_panel:bottom())
		self._mission_element_searchbox:register_callback(callback(self, self, "update_items_list", false))
		self._mission_element_searchbox:register_disconnect_callback(function()
			self._mission_element_searchbox.panel:enter_text(nil)
			self._mission_element_searchbox._enter_text_set = false
		end)
	end
end

function AdminMissionElementsList:set_element_panel(panel, data)
	if not data.element then
		error("Cannot Find Element")
	end

	local element_panel = panel:panel({
		name = tostring(data.element:id()),
		w = panel:w() - 20,
		h = data.h or panel:h()
	})

	-- element_panel:set_top(id_max * (element_panel:h() + 0.8))
	self._bg = element_panel:rect({
		name = "bg",
		visible = false,
		color = Color.black,
		layer = -1,
		alpha = 0.7,
		w = element_panel:w(),
		h = element_panel:h()
	})

	local element_box_panel = element_panel:panel({
		name = "element_box_panel",
		w = panel:w() - panel:w() / 3,
		h = element_panel:h()
	})

	element_panel:set_left(element_panel:left())

	local element_name_text = element_box_panel:text({
		name = "element_name_text",
		vertical = "center",
		valign = "center",
		align = "center",
		halign = "center",
		font = tweak_data.hud_players.ammo_font,
		text = data.element:editor_name(),
		font_size = 18
	})

	local center_x = element_box_panel:w() / 2
	local center_y = element_box_panel:h() / 2

	element_name_text:set_center_y(center_y)
	element_name_text:set_center_x(element_box_panel:center_x())

	-- Element id Text
	local element_id_text = element_panel:text({
		name = "element_id_text",
		vertical = "center",
		valign = "left",
		align = "left",
		halign = "center",
		font = tweak_data.hud_players.ammo_font,
		text = tostring(data.element:id()),
		font_size = 18
	})

	element_id_text:set_left(element_box_panel:right())

	return element_panel
end

function AdminMissionElementsList:update_items_list(scroll_position, search_list, search_text)
	if search_text then
		search_text = search_text:lower()
	end

	self._saved_search = search_text and search_text:lower() or nil

	for _, panel in ipairs(self._elements_scroll:items()) do
		self._scroll_panel:remove(panel)
	end

	self._elements_scroll:clear()

	for _, data in pairs(managers.mission:scripts()) do
		for _, element in pairs(data:elements()) do
			if string.is_nil_or_empty(search_text) or string.find(string.lower(element:editor_name()), search_text, nil, true) or 
				string.is_nil_or_empty(search_text) or string.find(tostring(element:id()), search_text, nil, true)
			then
				self._elements_scroll:add_item(self:set_element_panel(self._elements_scroll:canvas(),{
					element = element,
					h = self._mission_element_h
				}))
			end
		end
	end
end

function AdminMissionElementsList:set_element_info(element, panel, title_panel, w, h)
	if self._info_class then
		for _, cls in pairs(self._info_class) do
			if cls:parent() and alive(cls:parent()) then
				cls:destroy()
			end
		end
	end

	self._info_class = {}

	panel:set_visible(true)

	if title_panel and alive(title_panel) then
		title_panel:set_visible(true)
		title_panel:child("text"):set_text(element:editor_name() .. " : " .. tostring(element:id()))
	end

	local _w = w or 300
	local _h = h or 30

	-- Enabled
	self._info_class.enabled = AdminToggleButton:new(panel, {
		visible = true,
		text = "Enabled",
		state = element._values.enabled,
		w = _w,
		h = _h,
		x = 2
	})

	local enabled = self._info_class.enabled

	enabled:panel():set_top(2)

	enabled:set_callback(function()
		local state = not element._values.enabled
		element._values.enabled = state
	end)

	-- Trigger Times
	self._info_class.trigger_times = AdminInputBox:new(panel, self._ws, {
		visible = true,
		text = "Trigger Times",
		value = tostring(element._values.trigger_times),
		num_only = true,
		w = _w,
		h = _h
	})

	local trigger_times = self._info_class.trigger_times

	trigger_times:panel():set_top(enabled:panel():bottom() + 2)
	trigger_times:panel():set_left(enabled:panel():left())
	trigger_times:set_click_callback(function()
		self._selected = true
		managers.mouse_pointer:set_pointer_image("arrow")
	end)

	trigger_times:set_clickout_callback(function(time)
		self._selected = false
		element:set_trigger_times(time)
	end)

	-- Base Delay
	self._info_class.base_delay = AdminInputBox:new(panel, self._ws, {
		visible = true,
		text = "Base Delay",
		value = tostring(element._values.base_delay),
		num_only = true,
		w = _w,
		h = _h
	})

	local base_delay = self._info_class.base_delay

	base_delay:panel():set_top(trigger_times:panel():bottom() + 2)
	base_delay:panel():set_left(trigger_times:panel():left())
	base_delay:set_click_callback(function()
		self._selected = true
		managers.mouse_pointer:set_pointer_image("arrow")
	end)

	base_delay:set_clickout_callback(function(time)
		self._selected = false
		element._values.base_delay = time
	end)

	-- Random Delay
	self._info_class.base_delay_rand = AdminInputBox:new(panel, self._ws, {
		visible = true,
		text = "Random Delay",
		value = tostring(element._values.base_delay_rand or ""),
		num_only = true,
		w = _w,
		h = _h
	})

	local base_delay_rand = self._info_class.base_delay_rand

	base_delay_rand:panel():set_top(base_delay:panel():bottom() + 2)
	base_delay_rand:panel():set_left(base_delay:panel():left())
	base_delay_rand:set_click_callback(function()
		self._selected = true
		managers.mouse_pointer:set_pointer_image("arrow")
	end)

	base_delay_rand:set_clickout_callback(function(time)
		self._selected = false
		element._values.base_delay_rand = time
	end)

	-- Executed executed
	self._info_class.executed = AdminButton:new(panel, {
		visible = true,
		text = "Executed",
		w = _w,
		h = _h
	})

	local executed = self._info_class.executed

	executed:panel():set_top(base_delay_rand:panel():bottom() + 10)
	executed:panel():set_left(base_delay_rand:panel():left())

	executed:set_callback(function()
		element:on_executed()
	end)

	-- Link By -------------------------

	local function get_parent_elements(target_element)
		local parents = {}

		local target_id = target_element:id()  -- 目标 Element 的 ID

		-- 遍历所有脚本的所有 Element
		for script_name, script in pairs(managers.mission:scripts()) do
			for _, element in pairs(script:elements()) do
				-- 检查该 Element 的 on_executed 是否连接到了目标
				for _, link in ipairs(element._values.on_executed or {}) do
					if link.id == target_id then
						table.insert(parents, element)

						break  -- 找到后跳出当前循环
					end
				end
			end
		end

		return parents
	end

	self._info_class.link_by = AdminScrollList:new(panel, {
		scrollbar_padding = 0,
		bar_minimum_size = 16,
		padding = 0,
		w = _w + 20,
		h = 181,
		input_focus = true,
		title = "Link By"
	}, {
		padding = 0
	})

	local link_by = self._info_class.link_by

	link_by:panel():set_top(executed:panel():bottom() + 10)
	link_by:panel():set_left(executed:panel():left())

	link_by:add_lines_and_static_down_indicator()

	for _, _element in ipairs(get_parent_elements(element) or {}) do
		-- local _element = managers.mission:get_element_by_id(data.id)
		self._info_class["elements | " .. tostring(_element:id())] = AdminButton:new(link_by:canvas(), {
			visible = true,
			text = _element:editor_name(),
			w = _w,
			h = _h
		})

		element_button = self._info_class["elements | " .. tostring(_element:id())]

		element_button:set_callback(function()
			self:set_element_info(_element, self._ui.info, self._ui.title)
		end)

		link_by:add_item(element_button:panel())
	end

	for _, item in ipairs(link_by:items() or {}) do
		item:set_left(2)
	end

	-- Link To -------------------------

	self._info_class.on_executed = AdminScrollList:new(panel, {
		scrollbar_padding = 0,
		bar_minimum_size = 16,
		padding = 0,
		w = _w + 20,
		h = self._info_class.link_by:panel():h(),
		input_focus = true,
		title = "Link To"
	}, {
		padding = 0
	})

	local on_executed = self._info_class.on_executed

	on_executed:panel():set_top(link_by:panel():bottom() + 10)
	on_executed:panel():set_left(link_by:panel():left())

	on_executed:add_lines_and_static_down_indicator()

	for _, data in ipairs(element._values.on_executed or {}) do
		local _element = managers.mission:get_element_by_id(data.id)
		self._info_class["elements | " .. tostring(_element:id())] = AdminButton:new(on_executed:canvas(), {
			visible = true,
			text = _element:editor_name(),
			w = _w,
			h = _h
		})

		element_button = self._info_class["elements | " .. tostring(_element:id())]

		element_button:set_callback(function()
			self:set_element_info(_element, self._ui.info, self._ui.title)
		end)

		on_executed:add_item(element_button:panel())
	end

	for _, item in ipairs(on_executed:items() or {}) do
		item:set_left(2)
	end

	self._info_class.value_list = AdminScrollList:new(panel, {
		scrollbar_padding = 0,
		bar_minimum_size = 16,
		padding = 0,
		w = 300,
		h = panel:h(),
		input_focus = true
	}, {
		padding = 0
	})

	local value_list = self._info_class.value_list
	value_list:panel():set_left(on_executed:panel():right())
	value_list:add_lines_and_static_down_indicator()

	for name, v in pairs(element._values) do
		local _return = false

		for _, e_v in ipairs(self._value_exclude) do
			if name == e_v then
				_return = true
			end
		end

		if not self._info_class[name] and not _return then
			if type(v) == "boolean" then
				self._info_class[name] = AdminToggleButton:new(value_list:canvas(), {
					visible = true,
					text = name,
					state = v,
					w = value_list:canvas():w(),
					h = _h,
					x = 2
				})

				local button_v = self._info_class[name]

				button_v:set_callback(function(state)
					element._values[name] = state
				end)

				value_list:add_item(button_v:panel())
			elseif type(v) == "string" or type(v) == "number" then
				local is_num_only = type(v) == "number"

				self._info_class[name] = AdminInputBox:new(value_list:canvas(), self._ws, {
					visible = true,
					text = name,
					value = tostring(v or ""),
					num_only = is_num_only,
					w = value_list:canvas():w(),
					h = _h
				})

				local input_v = self._info_class[name]


				input_v:set_click_callback(function()
					self._selected = true
					managers.mouse_pointer:set_pointer_image("arrow")
				end)

				input_v:set_clickout_callback(function(value)
					self._selected = false
					element._values[name] = value
				end)

				value_list:add_item(input_v:panel())
			elseif type(v) == "table" then
				self._info_class[name] = AdminScrollList:new(value_list:canvas(), {
					scrollbar_padding = 0,
					bar_minimum_size = 16,
					padding = 0,
					w = value_list:panel():w() - 2,
					h = 181,
					input_focus = true,
					title = name,
					title_font_size = 50 - #name
				}, {
					padding = 0
				})

				local list_v = self._info_class[name]

				list_v:panel():rect({
					color = Color.black,
					w = list_v:canvas():w(),
					h = list_v:panel():h(),
					layer = -1,
					alpha = 0.5
				})

				list_v:add_lines_and_static_down_indicator()

				value_list:add_item(list_v:panel())

				for key, data in ipairs(v) do
					local _can_press = false
					local _callback = function() end
					local _text = tostring(data)
					local _m_text = ""

					if type(data) == "number" then
						local _element = managers.mission:get_element_by_id(data)
						if _element then
							_text = _element:editor_name()
							_m_text = tostring(_element:id())

							_can_press = true
							_callback = function()
								self:set_element_info(_element, self._ui.info, self._ui.title)
							end
						else
							local world_unit = managers.worlddefinition:get_unit(data)

							if world_unit then
								_text = "UnitId: " .. tostring(data)
							end
						end
					elseif type(data) == "table" then
						_text = "Unknown: " .. tostring(data.name)

						for k, v in pairs(data) do
						end
					end

					self._info_class[name .. tostring(key)] = AdminButton:new(list_v:canvas(), {
						visible = true,
						text = _text,
						can_press = _can_press,
						w = list_v:canvas():w(),
						h = _h
					})
					
					local button_in_list_v = self._info_class[name .. tostring(key)]

					local IdInfo = button_in_list_v:panel():text({
						name = "text",
						color = Color.white,
						vertical = "center",
						valign = "right",
						align = "right",
						halign = "center",
						font = tweak_data.hud_players.ammo_font,
						text = _m_text,
						font_size = 20
					})

					IdInfo:set_right(button_in_list_v:panel():right())
					IdInfo:set_center_y(button_in_list_v:panel():center_y())

					button_in_list_v:set_callback(_callback)

					list_v:add_item(button_in_list_v:panel())
				end
			elseif type(v) == "userdata" then
				local function set_vector3_panel(panel)
				end

				self:send_log(mvector3.x(v))
			end
		end
	end

	for _, item in ipairs(value_list:items() or {}) do
		item:set_left(2)
	end
end

function AdminMissionElementsList:send_log(...)
	local message = ""

	for _, v in ipairs({...}) do
		if message == "" then
			message = message .. tostring(v)
		else
			message = message .. " " .. tostring(v)
		end
	end

	managers.mission._fading_debug_output:script().log(tostring(message), color)
end

if GameSetup then
	Hooks:PostHook(GameSetup, "init_managers", "AdminMissionElementsList-GameSetup:init_managers", function(self, t, dt)
		 AdminMissionElementsList:init()
	end)
end

-- 触发按钮Lib
AdminButton = AdminButton or class()

function AdminButton:init(panel, data)
	self.class = "button"
	self._parent = panel
	self._can_press = not (tostring(data.can_press) == "false") and true or false

	self._panel = panel:panel({
		name = data.name,
		visible = tostring(data.visible) == "false" and false or true,
		layer = data.layer,
		w = data.w,
		h = data.h,
		x = data.x,
		y = data.y
	})

	local rect = self._panel:rect({
		name = "rect",
		visible = false,
		w = self._panel:w(),
		h = self._panel:h(),
		layer = -1,
		color = Color.black,
		alpha = 0.7
	})

	local text = self._panel:text({
		name = "text",
		color = data.text_color or Color.white,
		vertical = "center",
		valign = "left",
		align = "left",
		halign = "center",
		font = tweak_data.hud_players.ammo_font,
		text = data.text,
		font_size = data.font_size and size.font_size or 20
	})

	text:set_left(self._panel:left())
	text:set_center_y(self._panel:h() / 2)
end

function AdminButton:panel()
	return self._panel
end

function AdminButton:parent()
	return self._parent
end

function AdminButton:destroy()
	self:parent():remove(self._panel)
end

function AdminButton:callback()
	return self._callback
end

function AdminButton:set_callback(clbk)
	self._callback = clbk
end

function AdminButton:mouse_moved(o, x, y)
	if not self._can_press then
		return false
	end

	local mouse_inside = false

	if self:inside(x, y) then
		self._panel:child("rect"):set_visible(true)
		mouse_inside = true
	else
		self._panel:child("rect"):set_visible(false)
	end

	return mouse_inside
end

function AdminButton:mouse_pressed(button, x, y)
	if button == Idstring("0") then
		if self:inside(x, y) then
			if self:callback() then
				self:callback()()
			end
		end
	end
end

function AdminButton:mouse_released(button, x, y)
end

function AdminButton:inside(x, y)
	if self._panel:inside(x, y) then
		return true, "link"
	end

	return false, "arrow"
end

-- 切换按钮Lib
AdminToggleButton = AdminToggleButton or class()

function AdminToggleButton:init(panel, data)
	self.class = "toggle"
	self._parent = panel
	self._state = data.state or false

	self._panel = panel:panel({
		name = data.name,
		visible = tostring(data.visible) == "false" and false or true,
		layer = data.layer,
		w = data.w,
		h = data.h,
		x = data.x,
		y = data.y
	})

	local rect = self._panel:rect({
		name = "rect",
		visible = false,
		w = self._panel:w(),
		h = self._panel:h(),
		layer = -1,
		color = Color.black,
		alpha = 0.7
	})

	local tickbox_toggle = self._panel:bitmap({
		name = "tickbox_toggle",
		color = data.box_color or Color.white,
		texture = "guis/textures/menu_tickbox",
		texture_rect = {
			self._state and 24 or 0,
			0,
			24,
			24
		},
		w = data.box_size,
		h = data.box_size
	})

	tickbox_toggle:set_right(self._panel:right() - 4)
	tickbox_toggle:set_center_y(self._panel:h() / 2)

	local tickbox_text = self._panel:text({
		name = "tickbox_text",
		color = data.text_color or Color.white,
		vertical = "center",
		valign = "left",
		align = "left",
		halign = "center",
		font = tweak_data.hud_players.ammo_font,
		text = data.text,
		font_size = data.font_size and size.font_size or 20
	})

	tickbox_text:set_left(self._panel:left())
	tickbox_text:set_center_y(self._panel:h() / 2)
end

function AdminToggleButton:panel()
	return self._panel
end

function AdminToggleButton:parent()
	return self._parent
end

function AdminToggleButton:destroy()
	self:parent():remove(self._panel)
end

function AdminToggleButton:callback()
	return self._callback
end

function AdminToggleButton:set_callback(clbk)
	self._callback = clbk
end

function AdminToggleButton:mouse_moved(o, x, y)
	local mouse_inside = false

	if self:inside(x, y) then
		self._panel:child("rect"):set_visible(true)
		mouse_inside = true
	else
		self._panel:child("rect"):set_visible(false)
	end

	return mouse_inside
end

function AdminToggleButton:mouse_pressed(button, x, y)
	if button == Idstring("0") then
		if self:inside(x, y) then
			if self:callback() then
				self:callback()(self:toggle())
			end
		end
	end
end

function AdminToggleButton:mouse_released(button, x, y)
end

function AdminToggleButton:inside(x, y)
	if self._panel:inside(x, y) then
		return true, "link"
	end

	return false, "arrow"
end

function AdminToggleButton:toggle()
	local new_state = not self._state
	self:set_state(new_state)

	return new_state
end

function AdminToggleButton:set_state(state)
	self._state = state
	local box = self._panel:child("tickbox_toggle")

	box:set_texture_rect(
		state and 24 or 0,
		0,
		24,
		24
	)
end

-- 输入框Lib
AdminInputBox = AdminInputBox or class()

function AdminInputBox:init(panel, ws, data)
	self.class = "input"
	self._ws = ws
	self._parent = panel
	self._max_length = data.max_length or 100
	self._num_only = data.num_only

	self._panel = panel:panel({
		name = data.name,
		visible = tostring(data.visible) == "false" and false or true,
		layer = data.layer,
		w = data.w,
		h = data.h,
		x = data.x,
		y = data.y
	})

	self._name_text = self._panel:text({
		name = "name_text",
		vertical = "center",
		valign = "right",
		align = "right",
		halign = "center",
		text = data.text,
		alpha = 0.7,
		font = data.font or tweak_data.hud_players.ammo_font,
		font_size = data.font_size and size.font_size or 20,
		color = data.text_color
	})

	self._name_text:set_right(self._panel:right() - 5)
	self._name_text:set_center_y(self._panel:center_y())

	self._input_text = self._panel:text({
		name = "name_text",
		vertical = "center",
		valign = "left",
		align = "left",
		halign = "center",
		text = data.value,
		font = data.font or tweak_data.hud_players.ammo_font,
		font_size = data.font_size and size.font_size or 20,
		color = data.input_text_color
	})

	self._input_text:set_left(self._panel:left())
	self._input_text:set_center_y(self._panel:center_y())

	local bottom_line = self._panel:rect({
		name = "bottom_line",
		vertical = "center",
		align = "center",
		color = data.line_color,
		w = self._panel:w(),
		h = 1
	})

	bottom_line:set_bottom(self._panel:bottom())

	self._caret = self._panel:rect({
		name = "caret",
		w = 0,
		h = 0,
		x = 0,
		y = 0,
		layer = 2,
		color = Color(1, 1, 1, 1)
	})
end

function AdminInputBox:panel()
	return self._panel
end

function AdminInputBox:parent()
	return self._parent
end

function AdminInputBox:destroy()
	self:parent():remove(self._panel)
end

function AdminInputBox:mouse_moved(o, x, y)
	local mouse_inside = false

	if self:inside(x, y) then
		mouse_inside = true
	end

	return mouse_inside
end

function AdminInputBox:mouse_pressed(button, x, y)
	if button == Idstring("0") then
		if self:inside(x, y) then
			self:set_editing(true)
			self:click()
		elseif self._editing then
			self:set_editing(false)
		end
	end
end

function AdminInputBox:mouse_released(button, x, y)
end

function AdminInputBox:key_press(o, k)
	if self._editing then
		self:handle_key(k, true)
	end
end

function AdminInputBox:key_release(o, k)
	if self._editing then
		self:handle_key(k, false)
	end
end


function AdminInputBox:inside(x, y)
	if self._panel:inside(x, y) then
		return true, "link"
	end

	return false, "arrow"
end

function AdminInputBox:enter()
	self:enter_callback()()
end

function AdminInputBox:enter_callback()
	return self._enter_callback
end

function AdminInputBox:set_enter_callback(callback)
	self._enter_callback = callback
end

function AdminInputBox:click()
	if self:click_callback() then
		self:click_callback()()
	end
end

function AdminInputBox:click_callback()
	return self._click_callback
end

function AdminInputBox:set_click_callback(callback)
	self._click_callback = callback
end

function AdminInputBox:clickout()
	if self:clickout_callback() then
		self:clickout_callback()(self._num_only and tonumber(self._input_text:text()) or self._input_text:text())
	end
end

function AdminInputBox:clickout_callback()
	return self._clickout_callback
end

function AdminInputBox:set_clickout_callback(callback)
	self._clickout_callback = callback
end

function AdminInputBox:editing()
	return self._editing
end

function AdminInputBox:connect_search_input()
	self._ws:connect_keyboard(Input:keyboard())

	if _G.IS_VR then
		Input:keyboard():show_with_text(self._input_text:text())
	end

	self._panel:key_press(callback(self, self, "key_press"))
	self._panel:key_release(callback(self, self, "key_release"))

	self:update_caret()
	managers.menu_component:post_event("menu_enter")
end

function AdminInputBox:disconnect_search_input()
	self._ws:disconnect_keyboard()
	self._panel:key_press(nil)
	self._panel:key_release(nil)

	self:update_caret()
	managers.menu_component:post_event("menu_exit")

	if self._disconnect_callback then
		self._disconnect_callback(self._input_text:text())
	end
end

function AdminInputBox:update_caret()
	local text = self._input_text
	local caret = self._caret
	local s, e = text:selection()
	local x, y, w, h = text:selection_rect()
	local text_s = text:text()

	if #text_s == 0 then
		x = text:world_x()
		y = text:world_y()
	end

	h = text:h()

	if w < 3 then
		w = 3
	end

	if not self._editing then
		w = 0
		h = 0
	end

	caret:set_world_shape(x, y + 2, w, h - 4)
	self:set_blinking(s == e and self._editing)
end

function AdminInputBox.blink(o)
	while true do
		o:set_color(Color(0, 1, 1, 1))
		wait(0.3)
		o:set_color(Color.white)
		wait(0.3)
	end
end

function AdminInputBox:set_blinking(b)
	local caret = self._caret

	if b == self._blinking then
		return
	end

	if b then
		caret:animate(self.blink)
	else
		caret:stop()
	end

	self._blinking = b

	if not self._blinking then
		caret:set_color(Color.white)
	end
end

function AdminInputBox:start_input()
	self:trigger()
end

function AdminInputBox:trigger()
	if not self._editing then
		self:set_editing(true)
	else
		self:set_editing(false)
	end
end

function AdminInputBox:set_editing(editing)
	self._editing = editing

	if editing then
		self:connect_search_input()

		self._panel:enter_text(callback(self, self, "enter_text"))

		local n = utf8.len(self._input_text:text())

		self._input_text:set_selection(n, n)

		if _G.IS_VR then
			Input:keyboard():show_with_text(self._input_text:text(), self._max_length)
		end

		self._org_text = self._input_text:text()
		self:update_caret()
	else
		if self._num_only and not tonumber(self._input_text:text()) then
			self._input_text:set_text(self._org_text)
		end

		self._panel:enter_text(nil)
		self:disconnect_search_input()
		self:clickout()
	end
end

function AdminInputBox:enter_text(o, s)
	if not self._editing then
		return
	end

	if self._num_only and not tonumber(s) and not tonumber("0"..s.."1") then
		s = ""
	end

	if _G.IS_VR then
		self._input_text:set_text(s)
	else
		local s_len = utf8.len(self._input_text:text())
		s = utf8.sub(s, 1, self._max_length - s_len)

		self._input_text:replace_text(s)
	end

	self:update_caret()
end

function AdminInputBox:handle_key(k, pressed)
	local text = self._input_text
	local s, e = text:selection()
	local n = utf8.len(text:text())
	local d = math.abs(e - s)
	
	if pressed then
		if k == Idstring("backspace") then
			if s == e and s > 0 then
				text:set_selection(s - 1, e)
			end

			text:replace_text("")
		elseif k == Idstring("delete") then
			if s == e and s < n then
				text:set_selection(s, e + 1)
			end

			text:replace_text("")
		elseif k == Idstring("left") then
			if s < e then
				text:set_selection(s, s)
			elseif s > 0 then
				text:set_selection(s - 1, s - 1)
			end
		elseif k == Idstring("right") then
			if s < e then
				text:set_selection(e, e)
			elseif s < n then
				text:set_selection(s + 1, s + 1)
			end
		elseif k == Idstring("home") then
			text:set_selection(0, 0)
		elseif k == Idstring("end") then
			text:set_selection(n, n)
		end
	elseif k == Idstring("enter") then
		self:trigger()
	elseif k == Idstring("esc") then
		text:set_text(self._org_text)
		self:set_editing(false)
	end

	self:update_caret()
end

AdminScrollList = AdminScrollList or class(ScrollItemList)

function AdminScrollList:init(panel, data, canvas_config, ...)
	AdminScrollList.super.init(self, panel, data, canvas_config, ...)
	
	self.class = "list"
	self._panel = self._panel
	self._parent = panel
	self._h = data.h or panel:h() / 2
	self._dy = data.dy or 1

	if data.items then
		for _, item in ipairs(data.items) do
			self:add_item(item)
		end
	end

	local title = self:canvas():text({
		name = "title",
		color = Color.white,
		vertical = "top",
		valign = "right",
		align = "right",
		halign = "top",
		font = tweak_data.hud_players.ammo_font,
		text = data.title or "",
		alpha = 0.6,
		font_size = data.title_font_size or 50
	})

	title:set_right(self:canvas():w())
	title:set_top(self:canvas():top())

end

function AdminScrollList:panel()
	return self._panel
end

function AdminScrollList:parent()
	return self._parent
end

function AdminScrollList:destroy()
	self:parent():remove(self._panel)
end

function AdminScrollList:mouse_pressed(button, x, y)
	if button == Idstring("mouse wheel up") then
		return self:mouse_wheel_up(x, y)
	elseif button == Idstring("mouse wheel down") then
		return self:mouse_wheel_down(x, y)
	end

	self.super.mouse_pressed(self, button, x, y)
end

function AdminScrollList:mouse_wheel_up(x, y)
	if not alive(self._scroll) then
		return
	end

	self._scroll:scroll(x, y, self._dy)

	if not self._scroll:panel():inside(x, y) then
		return
	end

	return AdminScrollList.super.super.super.mouse_wheel_up(self, x, y)
end

function AdminScrollList:mouse_wheel_down(x, y)
	if not alive(self._scroll) then
		return
	end

	self._scroll:scroll(x, y, -self._dy)

	if not self._scroll:panel():inside(x, y) then
		return
	end

	return AdminScrollList.super.super.super.mouse_wheel_down(self, x, y)
end
