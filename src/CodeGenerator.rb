require "Exceptions"
require "parser/current"
# opt-in to most recent AST format:
Parser::Builders::Default.emit_lambda              = true
Parser::Builders::Default.emit_procarg0            = true
Parser::Builders::Default.emit_encoding            = true
Parser::Builders::Default.emit_index               = true
Parser::Builders::Default.emit_arg_inside_procarg0 = true
Parser::Builders::Default.emit_forward_arg         = true
Parser::Builders::Default.emit_kwargs              = true
Parser::Builders::Default.emit_match_pattern       = true

# pattern matching operators, implement object functions (nil?, is_a?, etc), case..when stmt, test more for roblox compatibility and interop with rojo
class CodeGenerator
    attr_reader :output

    def initialize(config, source)
        @source = source
        @debug_mode = !config["debugging"].nil? && config["debugging"] == true
        @output = ""
        @block = 0
        @line = 0

        @method_aliases = [:each, :each_with_index, :nil?, :to_s]
        @dont_return_nodes = [:lvasgn, :cvasgn, :ivasgn, :class, :module, :def, :puts, :if, :while, :until, :for, :break]
    end

    def generate()
        write(@debug_mode ? "-- " : "")
        write("local ruby = require(game.ReplicatedStorage.RubyLib)")
        self.newline
        self.newline

        root_node = Parser::CurrentRuby.parse(@source)
        walk_ast(root_node)
        if @debug_mode then
            puts root_node
        end
        @output
    end

    def write(text)
        @output << text
    end

    def writeln(text)
        write(text)
        self.newline
    end

    def newline()
        write("\n")
        write("    " * @block)
        @line += 1
    end

    def block()
        write("    " * @block)
        @block += 1
    end

    def end()
        @block -= 1
        self.newline
        write("end")
    end

    def walk_ast(node, *extra_data)
        if node.is_a?(Parser::AST::Node) then
            case node.type
            when :true, :false, :nil # literals
                write(node.type.to_s)
            when :float, :int
                write(node.children[0].to_s)
            when :str, :sym
                content = node.children[0].to_s
                write(self.quote_surround(content))
            when :array
                write("{")
                node.children.each do |child|
                    walk_ast(child)
                    write(child != node.children.last ? ", " : "")
                end
                write("}")
            when :hash
                write("{")
                node.children.each do |pair|
                    walk_ast(pair)
                    if pair != node.children.last then
                        self.newline
                    end
                end
                write("}")
            when :pair
                key, value = *node.children
                write(key.children[1].to_s)
                write(" = ")
                walk_ast(value)
            when :if # control flow
                add_end = extra_data[0]
                condition, block, elseif = *node.children
                is_nextif = !block.nil? && block.type == :next
                if is_nextif then
                    self.newline
                end
                write("if ")
                write(is_nextif ? "not (" : "")
                walk_ast(condition)
                write(is_nextif ? ")" : "")
                write(" then")
                self.block
                self.newline
                walk_ast(block)

                if !elseif.nil? then
                    @block -= 1
                    self.newline
                    write("else")
                    if elseif.type == :if then
                        walk_ast(elseif, false)
                    else
                        # @block -= 1
                        self.block
                        self.newline
                        walk_ast(elseif)
                    end
                end
                if (add_end.nil? && add_end != false) && !is_nextif then
                    self.end
                end
            when :while
                condition, block = *node.children
                write("while ")
                walk_ast(condition)
                write(" do")
                self.block

                walk_next_conditions(block)
                self.end
            when :until
                condition, block = *node.children
                write("repeat ")
                self.block

                walk_next_conditions(block)

                @block -= 1
                self.newline
                write("until ")
                walk_ast(condition)
            when :irange
                min, max = *node.children
                walk_ast(min)
                write(", ")
                walk_ast(max)
            when :for
                symbol, iterable, block = *node.children
                var_name = symbol.type == :mlhs ? symbol.children.map { |s| s.children[0].to_s }.join(", ") : symbol.children[0].to_s

                write("for #{iterable.type == :irange ? var_name : "_, " + var_name}")
                if iterable.type == :irange then
                    write(" = ")
                    walk_ast(iterable)
                else
                    write(" in pairs(")
                    walk_ast(iterable)
                    write(")")
                end
                write(" do")
                self.block

                walk_next_conditions(block)
                self.end
            when :break
                write("break")
            when :and # conditionals
                left_op, right_op = *node.children
                write("(")
                walk_ast(left_op)
                write(") and (")
                walk_ast(right_op)
                write(")")
            when :or
                left_op, right_op = *node.children
                write("(")
                walk_ast(left_op)
                write(") or (")
                walk_ast(right_op)
                write(")")
            when :send # operations
                send(node, *extra_data)
            when :index
                table, idx = *node.children
                walk_ast(table)
                write("[")
                walk_ast(idx)
                write("]")
            when :module # module defs
                module_def(node)
            when :class # class defs
                class_def(node)
            when :begin # blocks
                node.children.each do |child|
                    has_aliased = has_aliased_method?(child)
                    if child == node.children.last && ((child.type == :send && !is_assignment?(child)) || child.children[1] != :puts) && !@dont_return_nodes.include?(child.type) && !has_aliased then
                        write("return ")
                    end
                    if child.is_a?(Parser::AST::Node) then
                        walk_ast(child, *extra_data)
                    end
                    if child != node.children.last then
                        self.newline
                    end
                end
            when :def # defs
                set_args = extra_data[0]
                def_name = node.children[0].to_s.gsub("?", "").gsub("!", "")
                args = (set_args || node.children[1]).children
                arg_list = args.map { |arg| arg.children[0] }.join(", ")
                block = node.children[2]
                class_name = extra_data[4]
                if def_name == :initialize then return end

                write("function #{class_name.nil? ? "" : class_name + ":"}#{def_name}(#{arg_list})")
                self.block
                self.newline
                if !block.nil? then
                    if block.type != :begin && !is_assignment?(block) then
                        write("return ")
                    end
                    walk_ast(block, *extra_data)
                end
                self.end
            when :block # lambdas
                preceding, args_node, block = *node.children
                has_aliased_method, aliased_methods = *has_aliased_method?(preceding)
                args = args_node.children.map { |a| a.children[0].is_a?(Parser::AST::Node) ? a.children[0].children[0].to_s : a.children[0].to_s }
                walk_ast(preceding, nil, nil, true, preceding.children.last, args)
                if !has_aliased_method then
                    write("(function(#{args.join(", ")})")
                    self.block
                    self.newline
                    walk_ast(block)
                    self.end
                    write(")")
                end
                if has_aliased_method then
                    aliased_methods.each { |a| handle_aliased_suffix(a, block) }
                end
            when :block_pass # passing fns
                block = node.children[0]
                walk_ast(block)
            when :masgn # multiple assignment
                self.multiple_assign(node)
            when :op_asgn # op assignment
                name_node, op, val = *node.children
                if !@debug_mode then
                    walk_ast(name_node, true, true)
                    write(" #{op.to_s}= ")
                else
                    walk_ast(name_node, true, true)
                    write(" = ")
                    walk_ast(name_node, true, true)
                    write(" #{op.to_s} ")
                end
                if val.is_a?(Parser::AST::Node) then
                    walk_ast(val, *extra_data)
                else
                    write(val.children[0].to_s)
                end
            when :lvasgn, :gvasgn # local var assignment
                name, val = *node.children
                write((node.type == :lvasgn ? "local " : "") + (node.type == :gvasgn ? name.gsub!("$", "") : name.to_s) + " = ")
                if val.is_a?(Parser::AST::Node) then
                    walk_ast(val, *extra_data)
                else
                    write(val.children[0].to_s)
                end
            when :cvasgn
                class_name = extra_data[0]
                if !class_name.is_a?(String) then return warn("class name not string??") end

                self.instancevar_assign(node, "#{class_name}.")
            when :ivasgn
                var_name = node.children[0].to_s.gsub("@", "")
                readers, writers, accessors = *extra_data
                readers.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
                writers.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
                accessors.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
                location = self.get_v_location_name(var_name, readers, writers, accessors)
                self.instancevar_assign(node, location)
            when :lvar # variable indexing
                self.index_var(node)
            when :const
                write(node.children[1].to_s)
            else
                warn("unhandled ast node: #{node.type}")
            end
        elsif node.is_a?(Symbol) then
            write(" #{node.to_s} ")
        end
        @last_line = @line
    end

    def handle_aliased_suffix(a, block)
        case a
        when :each, :each_with_index
            walk_ast(block)
            self.end
		when :to_s
			write(")")
        when :nil?
            write(" == nil")
        end
    end

    def walk_next_conditions(node)
        nextif_nodes = node.children.filter { |n| n.is_a?(Parser::AST::Node) && n.type == :if && n.children[1].is_a?(Parser::AST::Node) && n.children[1].type == :next }
        node.children.each do |child|
            self.walk_ast(child)
        end
        node.children.each do |child|
            if !nextif_nodes.include?(child) then
                self.end
            end
        end
    end

    def is_guaranteed_function_call?(node, child, next_child)
        op = is_op?(node.children[1].to_s)
        is_assignment = is_assignment?(node)
        !next_child.nil? && !op && child.is_a?(Symbol) && !is_assignment
    end

    def send(node, *extra_data)
        if node.children[1] == :attr_accessor || node.children[1] == :attr_reader || node.children[1] == :attr_writer || node.children[1] == :include then return end

        dont_emit_function_check, not_function, is_block, block_method, block_args = *extra_data
        is_assignment = is_assignment?(node)
        op = is_op?(node.children[1].to_s)
        first_child = node.children[0]
        is_send = !first_child.nil? && first_child.is_a?(Parser::AST::Node) && first_child.children.length > 0 && !first_child.children[0].nil? && first_child.children[0].is_a?(Parser::AST::Node) && (first_child.children[0].type == :send || first_child.children[0].type == :lvar)
        child = node.children[node.children.length - 2]
        next_child = node.children.last
        guaranteed_function_call = is_guaranteed_function_call?(node, child, next_child)
        do_function_check = !guaranteed_function_call && (dont_emit_function_check || false) == false && !is_assignment && !op && !first_child.nil? && (first_child.type == :lvar || is_send) && !(is_block && block_method == node.children[1])
        if do_function_check then
            current_line = @output.split("\n")[@line]
            if current_line.nil? && is_block.nil? then
                write("local _ = ")
            end
            write("(type(")
        end
        is_aliased_method, aliased_methods = *has_aliased_method?(node, guaranteed_function_call, do_function_check)
        if is_aliased_method then
            aliased_methods.each do |a|
                case a
                when :each, :each_with_index
                    preceding = first_child
                    use_pairs = a == :each_with_index || @debug_mode
                    v, i = *block_args
                    write("for ")
                    write(use_pairs ? "#{a == :each_with_index ? i.to_s : "_"}, " : "")
                    write("#{v.to_s} in ")
                    write(use_pairs ? "pairs" : "ruby.list")
                    write("(")
                    walk_ast(preceding)
                    write(") do")
                    self.block
                    self.newline
				when :to_s
					# walk_ast(preceding)
					# write("tostring(")
					# walk_ast(first_child)
                when :nil?
                    walk_ast(first_child, true)
                end
            end
        end

        if !is_aliased_method then
            idx = 1
            node.children.each do |child|
                next_child = node.children[idx] # 1 based
                last_child = node.children[idx - 2]
                guaranteed_function_call = (is_guaranteed_function_call?(node, child, next_child) || ((!is_block.nil? || is_block) && block_method == child)) || false
                if child.is_a?(Parser::AST::Node) then
                    handle_send_child(node, child, idx, guaranteed_function_call, *extra_data)
                elsif child == :puts then
                    args = [*node.children]
                    args.shift(2)
                    write("print(")
                    args.each do |a|
                        walk_ast(a)
                        if a != args.last then
                            write(", ")
                        end
                    end
                    write(")")
                    break
                elsif child == :new then
                    write(".new(")
                else
                    next if node.children[1] == :puts
                    is_var = !node.nil? && node.children[1].is_a?(Symbol) && !self.is_op?(node.children[1].to_s)
                    obj_asgn = !first_child.nil? && (first_child.type == :lvar || first_child.type == :send)
                    write_dot = nil

                    sym = child.to_s
                    str = self.check_operator(sym)
                    if guaranteed_function_call then
                        str.gsub!("?", "")
                        str.gsub!("!", "")
                    end

                    is_aliased_method, aliased_methods = *has_aliased_method?(child, guaranteed_function_call, do_function_check)
                    if is_var && obj_asgn && !is_aliased_method then
                        write_dot = (do_function_check || (not_function || false) == true || is_assignment) || (!guaranteed_function_call && !(next_child.nil? && not_function == false))
                        write(write_dot ? "." : ":")
                    end
                    if !is_aliased_method then
                        write(str)
                    end
                    if (is_var && obj_asgn && !do_function_check && !not_function && !guaranteed_function_call && !is_assignment && !op && !write_dot) then
                        args = [*node.children]
                        args.shift(2)
                        write("(#{args.join(", ")})")
                    end
                    if guaranteed_function_call && !write_dot && (is_block.nil? || !is_block) then
                        write("(")
                        self.walk_ast(next_child)
                        write(")")
                        break
                    end
                end
                idx += 1
            end
        end

        if do_function_check then
            write(") == \"function\" and ")
            walk_ast(node, true, false)
            write(" or ")
            walk_ast(node, true, true)
            write(")")
        end
        if node.children[1] == :new then
            write(")")
        end
        if (!is_block || is_block.nil?) && is_aliased_method then
            aliased_methods.each { |a| handle_aliased_suffix(a, child) }
        end
    end

    def get_symbols_in(node)
        if node.nil? then return [] end
        descendants = []
        if node.is_a?(Parser::AST::Node) then
            node.children.each do |child|
                if child.is_a?(Parser::AST::Node) && child.children.length > 0 then
                    descendants.push(*get_symbols_in(child))
                else
                    descendants.push(child)
                end
            end
        else
            descendants.push(node)
        end
        descendants
    end

    def has_aliased_method?(node, guaranteed_function_call = false, do_function_check = false)
        symbols = get_symbols_in(node)

        aliased_methods = []
        symbols.each do |sym|
            is_aliased_method = @method_aliases.include?(sym)
            if is_aliased_method then
                aliased_methods.push(sym)
            end
        end

        if aliased_methods.length > 0 && (guaranteed_function_call || !do_function_check) then
            return true, aliased_methods.uniq
        else
            return false
        end
    end

    def handle_send_child(node, child, idx, guaranteed_function_call, *extra_data)
        next_child = node.children[idx] # idx is 1 based, not 0 based
        op = self.is_op?(node.children[1].to_s)
        case child.type
        when :str
            walk_ast(child)
            write(node.children.last != child ? ", " : "")
        when :int, :float, :true, :false, :send, :lvar
            walk_ast(child, *extra_data)
        when :ivar
            var_name = child.children[0].to_s.gsub("@", "")
            readers, writers, accessors = *extra_data
            readers.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
            writers.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
            accessors.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
            location = self.get_v_location_name(var_name, readers, writers, accessors) || "private."
            write(location + var_name)
        when :const
            walk_ast(child)
            if next_child.is_a?(Symbol) && next_child != :new then
                write(".")
            end
        when :begin
            handle_send_child(child, child.children[0], idx, *extra_data)
        when :block_pass

        else
            walk_ast(child, *extra_data)
            # var_name = child.children[0].to_s.strip
            # write(var_name)
        end
    end

    def is_assignment?(node)
        node.children[1].to_s.include?("=") || node.type == :lvasgn || node.type == :gvasgn
    end

    def primary_privates(inited_privates)
        inited_privates.each { |var| self.instancevar_assign(var) }
    end

    def class_initializer(class_name, class_block, initializer = nil, parent = nil, readers = nil, writers = nil, accessors = nil, inited_privates = nil)
        if initializer.nil? then
            writeln(")")
        end

        args = []
        if !initializer.nil? then
            args = initializer.children.map do |child|
                res = []
                if child.is_a?(Parser::AST::Node) && child.type == :super
                    vals = child.children.map do |a|
                        sym = a.type == :str ? self.quote_surround(a.children[0]) : a.children[0]
                    end
                    vals.each { |c| res.push(c) }
                    res
                end
            end
        end

        if args.length > 0 then
            self.newline
        end

        mixins = class_block.children.filter { |child| child.is_a?(Parser::AST::Node) && child.children[1] == :include }.map { |mixin| mixin.children[2].children[1].to_s }
        writeln("local include = {#{mixins.join(", ")}}")
        base_table = parent.nil? ? "{}" : "#{parent.children[1]}.new(#{args.compact.join(", ")})"
        writeln("local idxMeta = setmetatable(#{class_name}, { __index = #{base_table} })")
        writeln("idxMeta.__type = \"#{class_name}\"")

        write("for ")
        write(@debug_mode ? "_, " : "")
        write("mixin in ")
        write(@debug_mode ? "pairs" : "ruby.list")
        write("(include) do")
        @block -= 1
        self.newline
        @block += 1
        self.block
        write("for k, v in pairs(mixin) do")
        @block -= 2
        self.newline
        @block += 2
        self.block
        write("idxMeta[k] = v")
        self.end
        self.end
        self.newline


        writeln("local self = setmetatable({}, { __index = idxMeta })")
        writeln("self.attr_accessor = setmetatable({}, { __index = idxMeta.attr_accessor or {} })")
        writeln("self.attr_reader = setmetatable({}, { __index = idxMeta.attr_reader or {} })")
        writeln("self.attr_writer = setmetatable({}, { __index = idxMeta.attr_writer or {} })")
        writeln("self.writable = {}")
        writeln("self.private = {}")
        self.newline

        self.primary_privates(inited_privates)
        if !initializer.nil? then
            initializer_block = initializer.children[2]
            walk_ast(initializer_block, readers, writers, accessors)
        end

        self.newline
        self.newline
        writeln("return setmetatable(self, {")
        @block -= 1
        self.block
        writeln("__index = function(t, k)")
        self.block
        writeln("if not self.attr_reader[k] and not self.attr_accessor[k] and self.private[k] then")
        @block -= 1
        self.block
        @block += 2
        write("return nil")
        self.end
        self.newline
        write("return self.attr_reader[k] or self.attr_accessor[k] or #{class_name}[k]")
        self.end
        writeln(",")

        writeln("__newindex = function(t, k, v)")
        @block -= 2
        self.block
        writeln("if t.writable[k] or self.writable[k] or idxMeta.writable[k] then")
        @block += 1
        self.block
        @block -= 1
        writeln("if self.attr_writer[k] then")
        self.block
        @block += 1
        writeln("self.attr_writer[k] = v")
        write("elseif self.attr_accessor[k] then")
        @block += 1
        self.newline
        write("self.attr_accessor[k] = v")
        self.end
        @block -= 1
        self.newline

        write("else")
        @block += 1
        self.newline
        write("error(\"Attempt to write to un-writable attribute '\"..k..\"'\")")
        self.end
        self.end
        @block -= 1

        self.newline
        write("})")

        self.end
        @block -= 1
    end

    def get_class_initer_def(block)
        initializer = block.children.select {|def_node| def_node.children[0] == :initialize}[0]
        if initializer && initializer.children[0] == :initialize then
            initializer_args = initializer.children[1]
            arg_list = initializer_args.children.map { |arg| arg.children[0] }.join(", ")
            write("#{arg_list})")
        end
        initializer
    end

    def class_def(node)
        class_name = node.children[0].children[1].to_s
        parent = node.children[1]
        block = node.children[2]

        write("--classdef")
        self.newline
        write("local #{class_name} = {} do")
        self.newline
        @block += 1
        self.block
        @block -= 2
        self.block

        stmts = block.children.filter { |stmt| stmt.type == :cvasgn }
        stmts.each do |stmt|
            walk_ast(stmt, class_name)
            self.newline
        end

        added_initializer = false
        write("function #{class_name}.new(")
        @block += 1

        if !block.nil? then
            if block.type != :begin && !added_initializer then
                self.class_initializer(class_name, block, nil, parent)
                added_initializer = true
            end
            case block.type
            when :begin
                if !added_initializer then
                    readers = block.children.filter { |stmt| stmt.is_a?(Parser::AST::Node) && stmt.children[1] == :attr_reader }.map { |stmt| stmt.children[2].children[0].to_s }
                    writers = block.children.filter { |stmt| stmt.is_a?(Parser::AST::Node) && stmt.children[1] == :attr_writer }.map { |stmt| stmt.children[2].children[0].to_s }
                    accessors = block.children.filter { |stmt| stmt.is_a?(Parser::AST::Node) && stmt.children[1] == :attr_accessor }
                    inited_privates = block.children.filter { |stmt| stmt.is_a?(Parser::AST::Node) && stmt.type == :ivasgn }
                    initializer = self.get_class_initer_def(block)

                    self.class_initializer(class_name, block, initializer, parent, readers, writers, accessors, inited_privates)
                    added_initializer = true
                end
            when :send

            when :cvasgn
                walk_ast(node, class_name)
            end
        else
            self.class_initializer(class_name, block, nil, parent)
        end

        @block += 1
        self.end
    end

    def module_def(node)
        module_name = node.children[0].children[1].to_s
        block = node.children[1]

        writeln("--moduledef")
        writeln("local #{module_name} = {} do")
        @block += 1
        self.block
        @block -= 1

        if !block.nil? then
            _, args, def_block = *block.children
            new_block = block.updated(nil, ["#{module_name}:#{block.children[0].to_s}".to_sym, args, def_block])
            walk_ast(new_block)
        end

        self.end
    end

    def quote_surround(s)
        "\"#{s}\""
    end

    def instancevar_assign(node, location = nil)
        name_node, val_node = *node.children
        key = name_node.to_s.gsub("@", "")
        val = val_node.children[0].to_s
        if val_node.type == :str then
            val = self.quote_surround(val)
        end

        write((location || "self.private.") + "#{key} = #{val}")
        if location == "self.attr_accessor." || location == "self.attr_writer." then
            self.newline
            write("self.writable.#{key} = true")
        end
    end

    def multiple_assign(node)
        names_node, vals_node = *node.children

        added_keyword = false
        names_node.children.each do |name|
            if name.type == :lvasgn && !added_keyword then
                added_keyword = true
                write("local ")
            end
            var_name = name.children[0].to_s
            write((name.type == :gvasgn ? var_name.gsub!("$", "") : var_name) + (name == names_node.children.last ? "" : ", "))
        end
        write(" = ")

        vals_node.children.each do |val|
            write(val.children[0].to_s + (val == vals_node.children.last ? "" : ", "))
        end
    end

    def get_v_location_name(var_name, readers, writers, accessors)
        if !readers.nil? && readers.include?(var_name) then
            "self.attr_reader."
        elsif !writers.nil? && writers.include?(var_name) then
            "self.attr_writer."
        elsif !accessors.nil? && accessors.include?(var_name) then
            "self.attr_accessor."
        end
    end

    def is_op?(str)
        operators = %w(+ - * / += -= *= /= %= **= % ** & | ^ > >= < <= == === != =~ !~ ! && || =)
        operators.include?(str.strip)
    end

    def check_operator(str)
        if self.is_op?(str)
            if str == "=~" || str == "!~" || str == "^" || str == "&" || str == "|" then
                raise Exceptions::UnsupportedBitOpError.new
            end
            " #{str.gsub("!=", "~=").gsub("**", "^").gsub("===", "==").gsub("&&", "and").gsub("||", "or").gsub("!", "not")} "
        else
            str.gsub("=", " = ")
        end
    end

    def index_var(node)
        write(node.children[0].to_s.strip)
    end
end
