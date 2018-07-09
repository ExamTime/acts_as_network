require "acts_as_network/version"
require "active_record"

#
# ActsAsNetwork contains
# * ActsAsNetwork::Network::ClassMethods - provides the actual acts_as_network ActiveRecord functionality
# * ActsAsNetwork::UnionCollection - the basis for the "union" capability that allows acts_as_network
#   to expose both inbound and outbound relationships in a single collection
#
module ActsAsNetwork
   # = UnionCollection
   # UnionCollection provides useful application-space functionality
   # for emulating set unions acrosss ActiveRecord collections. 
   #
   # A UnionCollection can be initialized with zero or more sets, 
   # although generally it must contain at least two to do anything 
   # useful. Once initialized, the UnionCollection itself will 
   # act as an array containing all of the records from each of its 
   # member sets. The following will create a union object containing
   # the unique results of each individual find
   #
   #   union = ActsAsNetwork::UnionCollection.new(
   #     Person.where("id <= 1"),                # set 0
   #     Person.where("id >= 10 AND id <= 15"),  # set 1
   #     Person.where("id >= 20")                # set 2
   #   )
   #
   # UnionCollection will also allow you to execute a find_by_id query
   # across the member sets
   #
   #   union.find(30)
   #
   # would retrieve the record from set 2 with id == 30, and
   #
   #   union.find(9)
   #
   # would throw an #ActiveRecord::RecordNotFound exception because that id
   # is specifically excluded from the union's member sets.
   #
   # UnionCollection operates according to the following rules:
   #
   # * <tt>find(ids)</tt> - will look through all member sets in search
   #   of records with the given ids. #ActiveRecord::RecordNotFound will 
   #   be raised unless all the IDs are located.
   #
   class UnionCollection

     # UnionCollection should be initialized with a list of ActiveRecord collections
     #
     #   union = ActsAsNetwork::UnionCollection.new(
     #     Person.where("id <= 1"),      # dynamic find set
     #     Person.managers               # a model association 
     #   )
     #
     def initialize(*sets)
       @sets = sets || []
       @sets.compact!     # remove nil elements
     end

     # Supports finding by an id or list of ids
     #
     #   union.find(9)
     #   union.find([9, 10, 11])
     #
     # Invokes method against set1, catching ActiveRecord::RecordNotFound.
     # if exception is raised try the method execution against set2
     def find(*ids)
       res = @sets.reduce([]) do |memo, set|
         memo << set.where(id: ids) unless set.empty?
         memo
       end.flatten

       res.uniq!
       if ids.uniq.size != res.size
         #FIXME
         raise ActiveRecord::RecordNotFound.new "Couldn't find all records with IDs (#{ids.join ','})"
       end
       ids.size == 1 ? res[0] : res
     end

     def to_a
       load_sets
       @arr
     end

     private

     def load_sets
       @arr = []
       @sets.each{|set| @arr.concat set unless set.nil?} unless @sets.nil?
       @arr.uniq!
     end

     # Handle find_by convenience methods
     def method_missing(method_id, *args, &block)
       load_sets
       @arr.send method_id, *args, &block
     end
   end

   module Network #:nodoc:
     def self.included(base)
       base.extend ClassMethods
     end

     module ClassMethods
       # = acts_as_network
       #
       # ActsAsNetwork expects a few things to be present before it is
       # called. Namely, you need to establish the existance of either
       # 1. a HABTM join table; or
       # 2. an intermediate Join model
       # 
       # == HABTM
       #
       # In the first case, +acts_as_network+ will assume that your HABTM table is named
       # in a self-referential manner based on the model name. i.e. if your model is called
       # +Person+ it will assume the HABTM join table is called +people_people+.
       # It will also default the +foreign_key+ column to be named after the model: +person_id+. 
       # The default +association_foreign_key+ column will be the +foreign_key+ name with +_target+
       # appended.
       #
       #   acts_as_network :friends
       #
       # You can override any of these options in your call to +acts_as_network+. The
       # following will use a join table named +friends+ with a foreign key of +person_id+
       # and an association foreign key of +friend_id+
       #
       #   acts_as_network :friends, :join_table => :friends, :foreign_key => 'person_id', :association_foreign_key => 'friend_id'
       #
       # == Join Model
       #
       # In the second case +acts_as_network+ will need to be told which model to use to perform the join - this is 
       # accomplished by passing a symbol for the join model to the <tt>:through</tt> option. So, with a join model called invites
       # use:
       #
       #   acts_as_network :friends, :through => :invites
       #
       # The same assumptions are made relative to the foreign_key and association_foreign_key columns, which can be overriden using
       # the same options. It may be useful to include <tt>:conditions</tt> as well depending on the specific requirements of the 
       # join model. The following will create a network relation using a join model named +Invite+ with a foreign_key of 
       # +person_id+, an association_foreign_key of +friend_id+, where the Invite's +is_accepted+ field
       # is true.
       #
       #   acts_as_network :friends, :through => :invites, :foreign_key => 'person_id', 
       #                   :association_foreign_key => 'friend_id', [:conditions => "is_accepted = ?", true]
       #
       # The valid configuration options that can be passed to +acts_as_network+ follow:
       #
       # * <tt>:through</tt> - class to use for has_many :through relationship. If omitted acts_as_network 
       #   will fall back on a HABTM relation
       # * <tt>:join_table</tt> - when using a simple HABTM relation, this allows you to override the 
       #   name of the join table. Defaults to <tt>model_model</tt> format, i.e. people_people
       # * <tt>:foreign_key</tt> - name of the foreign key for the origin side of relation - 
       #   i.e. person_id.
       # * <tt>:association_foreign_key</tt> - name of the foreign key for the target side, 
       #   i.e. person_id_target. Defaults to the same value as +foreign_key+ with a <tt>_target</tt> suffix
       # * <tt>:conditions</tt> - optional, lamba representing standard ActiveRecord SQL contition clause
       #
       def acts_as_network(relationship, options = {})
         configuration = { 
           :foreign_key => name.foreign_key, 
           :association_foreign_key => "#{name.foreign_key}_target", 
           :join_table => "#{name.tableize}_#{name.tableize}"
         }
         configuration.update(options) if options.is_a?(Hash)

         if configuration[:through].nil?
           has_and_belongs_to_many "#{relationship}_out".to_sym,
             configuration.fetch(:conditions, lambda{ where("1=1") }),
             :class_name => name,
             :foreign_key => configuration[:foreign_key],
             :association_foreign_key => configuration[:association_foreign_key],
             :join_table => configuration[:join_table]

           has_and_belongs_to_many "#{relationship}_in".to_sym,
             configuration.fetch(:conditions, lambda{ where("1=1") }),
             :class_name => name,
             :foreign_key => configuration[:association_foreign_key],
             :association_foreign_key => configuration[:foreign_key],
             :join_table => configuration[:join_table]

         else

           through_class = configuration[:through].to_s.classify
           through_sym = configuration[:through]

           # a node has many outbound relationships
           has_many "#{through_sym}_out".to_sym,
             :class_name => through_class,
             :foreign_key => configuration[:foreign_key]
           has_many "#{relationship}_out".to_sym,
             configuration.fetch(:conditions, lambda{ where("1=1") }),
             :through => "#{through_sym}_out".to_sym,
             :source => "#{name.tableize.singularize}_target",
             :foreign_key => configuration[:foreign_key]

           # a node has many inbound relationships
           has_many "#{through_sym}_in".to_sym,
             :class_name => through_class, 
             :foreign_key => configuration[:association_foreign_key]
           has_many "#{relationship}_in".to_sym,
             configuration.fetch(:conditions, lambda{ where("1=1") }),
             :through => "#{through_sym}_in".to_sym, 
             :source => name.tableize.singularize,
             :foreign_key => configuration[:association_foreign_key]

           # when using a join model, define a method providing a unioned view of all the join
           # records. i.e. if People acts_as_network :contacts :through => :invites, this method
           # is defined as def invites
           class_eval <<-EOV
             acts_as_union :#{through_sym}, [ :#{through_sym}_in, :#{through_sym}_out ]
           EOV

         end

         # define the accessor method for the reciprocal network relationship view itself. 
         # i.e. if People acts_as_network :contacts, this method is defind as def contacts
         class_eval <<-EOV
           acts_as_union :#{relationship}, [ :#{relationship}_in, :#{relationship}_out ]
         EOV
       end
     end
   end

   module Union
     def self.included(base)
       base.extend ClassMethods
     end

     module ClassMethods
       # = acts_as_union
       # acts_as_union simply presents a union'ed view of one or more ActiveRecord 
       # relationships (has_many or has_and_belongs_to_many, acts_as_network, etc).
       # 
       #   class Person < ActiveRecord::Base
       #     acts_as_network :friends
       #     acts_as_network :colleagues, :through => :invites, :foreign_key => 'person_id', 
       #                     :conditions => ["is_accepted = ?", true]
       #     acts_as_union   :aquantainces, [:friends, :colleagues]
       #   end
       #
       # In this case a call to the +aquantainces+ method will return a UnionCollection on both 
       # a person's +friends+ and their +colleagues+. Likewise, finder operations will work accross 
       # the two distinct sets as if they were one. Thus, for the following code
       # 
       #   stephen = Person.find_by_name('Stephen')
       #   # search for user by login
       #   billy = stephen.aquantainces.find_by_name('Billy')
       #
       # both Stephen's +friends+ and +colleagues+ collections would be searched for someone named Billy.
       # 
       # +acts_as_union+ doesn't accept any options.
       #
       def acts_as_union(relationship, methods)
         # define the accessor method for the union.
         # i.e. if People acts_as_union :jobs, this method is defined as def jobs
         class_eval <<-EOV
           def #{relationship}
             UnionCollection.new(#{methods.collect{|m| "self.#{m.to_s}"}.join(',')})
           end
         EOV
       end
    end
  end
end

ActiveRecord::Base.send :include, ActsAsNetwork::Network
ActiveRecord::Base.send :include, ActsAsNetwork::Union
