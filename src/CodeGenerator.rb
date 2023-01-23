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

class CodeGenerator
    attr_reader :output

    def initialize(config, source)
        @source = source
        @debug_mode = !config["debugging"].nil? && config["debugging"] == true
        @output = ""
        @block = 0
        @line = 0
    end

    def generate()
        self.write(@debug_mode ? "-- " : "")
        self.write("local ruby = require(game.ReplicatedStorage.RubyLib)")
        self.newline
        self.newline

        root_node = Parser::CurrentRuby.parse(@source)
        self.walk_ast(root_node)
        puts root_node
        @output
    end

    def write(text)
        @output << text
    end

    def writeln(text)
        self.write(text)
        self.newline
    end

    def newline()
        self.write("\n")
        self.write("    " * @block)
        @line += 1
    end

    def block()
        self.write("    " * @block)
        @block += 1
    end

    def end()
        @block -= 1
        self.newline
        self.write("end")
    end

    def walk_ast(node, *extra_data)
        if node.is_a?(Parser::AST::Node) then
            case node.type
            when :true, :false # literals
                self.write(node.type.to_s)
            when :float, :int
                self.write(node.children[0].to_s)
            when :str, :sym
                content = node.children[0].to_s
                self.write(self.quote_surround(content))
            when :array
                idx = 1
                self.write("{")
                node.children.each do |child|
                    self.walk_ast(child)
                    self.write(child != node.children.last ? ", " : "")
                    idx += 1
                end
                self.write("}")
            when :if # control flow
                add_end = extra_data[0]
                condition, block, elseif = *node.children
                self.write("if ")
                self.walk_ast(condition)
                self.write(" then")
                self.block
                self.newline
                self.walk_ast(block)

                if !elseif.nil? then
                    @block -= 1
                    self.newline
                    self.write("else")
                    if elseif.type == :if then
                        self.walk_ast(elseif, false)
                    else
                        # @block -= 1
                        self.block
                        self.newline
                        self.walk_ast(elseif)
                    end
                end
                if add_end.nil? && add_end != false then
                    self.end
                end
            when :while
                condition, block = *node.children
                self.write("while ")
                self.walk_ast(condition)
                self.write(" do")
                self.block
                self.newline
                self.walk_ast(block)
                self.end
            when :until
                condition, block = *node.children
                self.write("repeat ")
                self.block
                self.newline
                self.walk_ast(block)

                @block -= 1
                self.newline
                self.write("until ")
                self.walk_ast(condition)
            when :irange
                min, max = *node.children
                self.walk_ast(min)
                self.write(", ")
                self.walk_ast(max)
            when :for
                symbol, iterable, block = *node.children
                var_name = symbol.type == :mlhs ? symbol.children.map { |s| s.children[0].to_s }.join(", ") : symbol.children[0].to_s

                self.write("for #{iterable.type == :irange ? var_name : "_, " + var_name}")
                if iterable.type == :irange then
                    self.write(" = ")
                    self.walk_ast(iterable)
                else
                    self.write(" in pairs(")
                    self.walk_ast(iterable)
                    self.write(")")
                end
                self.write(" do")
                self.block
                self.newline
                self.walk_ast(block)
                self.end
            when :break
                self.write("break")
            when :and # conditionals
                left_op, right_op = *node.children
                self.write("(")
                self.walk_ast(left_op)
                self.write(") and (")
                self.walk_ast(right_op)
                self.write(")")
            when :or
                left_op, right_op = *node.children
                self.write("(")
                self.walk_ast(left_op)
                self.write(") or (")
                self.walk_ast(right_op)
                self.write(")")
            when :send # operations
                if node.children[1] == :attr_accessor || node.children[1] == :attr_reader || node.children[1] == :attr_writer || node.children[1] == :include then return end

                dont_emit_function_check, not_function, is_block, block_method = *extra_data
                is_assignment = self.is_assignment?(node)
                op = self.is_op?(node.children[1].to_s)
                first_child = node.children[0]
                is_send = !first_child.nil? && first_child.is_a?(Parser::AST::Node) && first_child.children.length > 0 && !first_child.children[0].nil? && first_child.children[0].is_a?(Parser::AST::Node) && (first_child.children[0].type == :send || first_child.children[0].type == :lvar)
                do_function_check = (dont_emit_function_check || false) == false && !is_assignment && !op && !first_child.nil? && (first_child.type == :lvar || is_send) && !(is_block && block_method == node.children[1])
                if do_function_check then
                    current_line = @output.split("\n")[@line]
                    if current_line.nil? then
                        self.write("local _ = ")
                    end
                    self.write("(type(")
                end
                idx = 1
                node.children.each do |child|
                    if child.is_a?(Parser::AST::Node) then
                        self.handle_send_child(node, child, idx, *extra_data)
                    elsif child == :puts then
                        self.write("print(")
                    elsif child == :new then
                        self.write(".new(")
                    else
                        is_var = !node.nil? && node.children[1].is_a?(Symbol) && !self.is_op?(node.children[1].to_s)
                        obj_asgn = !first_child.nil? && (first_child.type == :lvar || first_child.type == :send)
                        if is_var && obj_asgn then
                            self.write((do_function_check || (not_function || false) == true || is_assignment ? "." : ":"))
                        end

                        sym = child.to_s
                        self.write(self.check_operator(sym))
                        if obj_asgn && !do_function_check && !not_function && !is_assignment && !op then
                            args = [*node.children]
                            args.shift(2)
                            self.write("(#{args.join(", ")})")
                        end
                    end
                    idx += 1
                end
                if do_function_check then
                    self.write(") == \"function\" and ")
                    self.walk_ast(node, true)
                    self.write(" or ")
                    self.walk_ast(node, true, true)
                    self.write(")")
                end
                if node.children[1] == :puts || node.children[1] == :new then
                    self.write(")")
                end
            when :module # module defs
                self.module_def(node)
            when :class # class defs
                self.class_def(node)
            when :begin # blocks
                idx = 1
                dont_return_nodes = [:lvasgn, :cvasgn, :ivasgn, :class, :module, :def, :puts, :if, :while, :until, :for, :break]
                node.children.each do |child|
                    if child == node.children.last && (child.type == :send && !self.is_assignment?(child)) && child.children[1] != :puts && !dont_return_nodes.include?(child.type) then
                        self.write("return ")
                    end
                    if child.is_a?(Parser::AST::Node) then
                        self.walk_ast(child, *extra_data)
                    end
                    if idx != node.children.length then
                        self.newline
                    end
                    idx += 1
                end
            when :def # defs
                set_args = extra_data[0]
                def_name = node.children[0]
                args = (set_args || node.children[1]).children
                arg_list = args.map { |arg| arg.children[0] }.join(", ")
                block = node.children[2]
                class_name = extra_data[4]
                if def_name == :initialize then return end

                self.writeln("function #{class_name.nil? ? "" : class_name + ":"}#{def_name.to_s}(#{arg_list})")
                self.block
                if !block.nil? then
                    self.walk_ast(block, *extra_data)
                end
                self.end
            when :block
                preceding, args_node, block = *node.children
                self.walk_ast(preceding, nil, nil, true, preceding.children.last)
                @output.slice!(@output.length - 2 .. output.length - 1) # lil trick hehe, be careful tho

                args = args_node.children.map { |a| a.children[0].children[0].to_s }
                self.write("(function(#{args.join(", ")})")
                self.block
                self.newline
                self.walk_ast(block)
                self.end
                self.write(")")
            when :masgn # multiple assignment
                self.multiple_assign(node)
            when :op_asgn # op assignment
                name_node, op, val = *node.children
                if !@debug_mode then
                    self.walk_ast(name_node, true, true)
                    self.write(" #{op.to_s}= ")
                else
                    self.walk_ast(name_node, true, true)
                    self.write(" = ")
                    self.walk_ast(name_node, true, true)
                    self.write(" #{op.to_s} ")
                end
                if val.is_a?(Parser::AST::Node) then
                    self.walk_ast(val, *extra_data)
                else
                    self.write(val.children[0].to_s)
                end
            when :lvasgn, :gvasgn # local var assignment
                name, val = *node.children
                self.write((node.type == :lvasgn ? "local " : "") + (node.type == :gvasgn ? name.gsub!("$", "") : name.to_s) + " = ")
                if val.is_a?(Parser::AST::Node) then
                    self.walk_ast(val, *extra_data)
                else
                    self.write(val.children[0].to_s)
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
                self.write(node.children[1].to_s)
            else
                warn("unhandled ast node: #{node.type}")
            end
        elsif node.is_a?(Symbol) then
            self.write(" #{node.to_s} ")
        end
        @last_line = @line
    end

    def handle_send_child(node, child, idx, *extra_data)
        next_child = node.children[idx] # idx is 1 based, not 0 based
        case child.type
        when :str
            self.walk_ast(child)
            self.write(node.children.last != child ? ", " : "")
        when :int, :float, :true, :false, :send, :lvar
            self.walk_ast(child, *extra_data)
        when :ivar
            var_name = child.children[0].to_s.gsub("@", "")
            readers, writers, accessors = *extra_data
            readers.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
            writers.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
            accessors.map! { |n| (n.is_a?(String) ? n : n.children[2].children[0]).to_s }
            location = self.get_v_location_name(var_name, readers, writers, accessors) || "private."
            self.write(location + var_name)
        when :const
            self.walk_ast(child)
            if next_child.is_a?(Symbol) && next_child != :new then
                self.write(".")
            end
        when :begin
            self.handle_send_child(child, child.children[0], idx, *extra_data)
        else
            var_name = child.children[0].to_s.strip
            self.write(var_name)
        end
    end

    def is_assignment?(node)
        node.children[1].to_s.include?("=")
    end

    def primary_privates(inited_privates)
        inited_privates.each { |var| self.instancevar_assign(var) }
    end

    def class_initializer(class_name, class_block, initializer = nil, parent = nil, readers = nil, writers = nil, accessors = nil, inited_privates = nil)
        if initializer.nil? then
            self.writeln(")")
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
        self.writeln("local include = {#{mixins.join(", ")}}")
        base_table = parent.nil? ? "{}" : "#{parent.children[1]}.new(#{args.compact.join(", ")})"
        self.writeln("local idxMeta = setmetatable(#{class_name}, { __index = #{base_table} })")

        self.write("for _, mixin in pairs(include) do")
        @block -= 1
        self.newline
        @block += 1
        self.block
        self.write("for k, v in pairs(mixin) do")
        @block -= 2
        self.newline
        @block += 2
        self.block
        self.write("idxMeta[k] = v")
        self.end
        self.end
        self.newline


        self.writeln("local self = setmetatable({}, { __index = idxMeta })")
        self.writeln("self.attr_accessor = setmetatable({}, { __index = idxMeta.attr_accessor or {} })")
        self.writeln("self.attr_reader = setmetatable({}, { __index = idxMeta.attr_reader or {} })")
        self.writeln("self.attr_writer = setmetatable({}, { __index = idxMeta.attr_writer or {} })")
        self.writeln("self.writable = {}")
        self.writeln("self.private = {}")
        self.newline

        self.primary_privates(inited_privates)
        if !initializer.nil? then
            initializer_block = initializer.children[2]
            self.walk_ast(initializer_block, readers, writers, accessors)
        end

        self.newline
        self.newline
        self.writeln("return setmetatable(self, {")
        @block -= 1
        self.block
        self.writeln("__index = function(t, k)")
        self.block
        self.writeln("if not self.attr_reader[k] and not self.attr_accessor[k] and self.private[k] then")
        @block -= 1
        self.block
        @block += 2
        self.write("return nil")
        self.end
        self.newline
        self.write("return self.attr_reader[k] or self.attr_accessor[k] or #{class_name}[k]")
        self.end
        self.writeln(",")

        self.writeln("__newindex = function(t, k, v)")
        @block -= 2
        self.block
        self.writeln("if t.writable[k] or self.writable[k] or idxMeta.writable[k] then")
        @block += 1
        self.block
        @block -= 1
        self.writeln("if self.attr_writer[k] then")
        self.block
        @block += 1
        self.writeln("self.attr_writer[k] = v")
        self.write("elseif self.attr_accessor[k] then")
        @block += 1
        self.newline
        self.write("self.attr_accessor[k] = v")
        self.end
        @block -= 1
        self.newline

        self.write("else")
        @block += 1
        self.newline
        self.write("error(\"Attempt to write to un-writable attribute '\"..k..\"'\")")
        self.end
        self.end
        @block -= 1

        self.newline
        self.write("})")

        self.end
        @block -= 1
    end

    def get_class_initer_def(block)
        initializer = block.children.select {|def_node| def_node.children[0] == :initialize}[0]
        if initializer && initializer.children[0] == :initialize then
            initializer_args = initializer.children[1]
            arg_list = initializer_args.children.map { |arg| arg.children[0] }.join(", ")
            self.write("#{arg_list})")
        end
        initializer
    end

    def class_def(node)
        class_name = node.children[0].children[1].to_s
        parent = node.children[1]
        block = node.children[2]

        self.write("--classdef")
        self.newline
        self.write("local #{class_name} = {} do")
        self.newline
        @block += 1
        self.block
        @block -= 2
        self.block

        stmts = block.children.filter { |stmt| stmt.type == :cvasgn }
        stmts.each do |stmt|
            self.walk_ast(stmt, class_name)
            self.newline
        end

        added_initializer = false
        self.write("function #{class_name}.new(")
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
                self.walk_ast(node, class_name)
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

        self.writeln("--moduledef")
        self.writeln("local #{module_name} = {} do")
        @block += 1
        self.block
        @block -= 1

        if !block.nil? then
            _, args, def_block = *block.children
            new_block = block.updated(nil, ["#{module_name}:#{block.children[0].to_s}".to_sym, args, def_block])
            self.walk_ast(new_block)
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

        self.write((location || "self.private.") + "#{key} = #{val}")
        if location == "self.attr_accessor." || location == "self.attr_writer." then
            self.newline
            self.write("self.writable.#{key} = true")
        end
    end

    def multiple_assign(node)
        names_node, vals_node = *node.children

        nidx = 1
        added_keyword = false
        names_node.children.each do |name|
            if name.type == :lvasgn && !added_keyword then
                added_keyword = true
                self.write("local ")
            end
            var_name = name.children[0].to_s
            self.write((name.type == :gvasgn ? var_name.gsub!("$", "") : var_name) + (nidx == names_node.children.length ? "" : ", "))
            nidx += 1
        end
        self.write(" = ")

        vidx = 1
        vals_node.children.each do |val|
            self.write(val.children[0].to_s + (vidx == vals_node.children.length ? "" : ", "))
            vidx += 1
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
        operators = %w(+ - * / += -= *= /= %= **= % ** & | ^ > >= < <= == === != =~ !~ && || =)
        operators.include?(str.strip)
    end

    def check_operator(str)
        if self.is_op?(str)
            if str == "=~" || str == "!~" || str == "^" || str == "&" || str == "|" then
                raise Exceptions::UnsupportedBitOpError.new
            end
            " #{str.gsub("!=", "~=").gsub("**", "^").gsub("===", "==").gsub("&&", "and").gsub("||", "or")} "
        else
            str.gsub("=", " = ")
        end
    end

    def index_var(node)
        self.write(node.children[0].to_s.strip)
    end
end
